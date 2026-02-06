import Testing
import NIOCore
import NIOPosix
import Foundation
import Logging
import LoggingAdvanced
@testable import OPA
@preconcurrency import AnyCodable

/// OPA SDK 使用示例 / Quick Start
///
/// 本文件旨在作为开发者的 "快速上手指南" (Quick Start Guide)。
/// 它演示了如何在 Swift 项目中集成 OPA 客户端，涵盖了从初始化到
/// 策略管理、数据管理、查询以及高级编译功能的完整流程。
///
/// **核心概念**:
/// - **Client**: `OPA` 类是核心入口，负责与 OPA Server 交互。
/// - **EventLoop**: 基于 SwiftNIO，需要管理 `EventLoopGroup` 的生命周期。
/// - **Controllers**: 通过 `opa.policy`, `opa.data`, `opa.query` 等控制器访问不同模块。
/// - **Concurrency**: 全面支持 Swift `async/await` 现代并发模型。
@Suite("OPA 使用示例", .serialized, .enabled(if: TestingShared.opaListening))
struct UsageExampleTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .examples {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    // MARK: - 1. 客户端初始化 (Initialization)
    
    /// 辅助方法：创建一个标准配置的 OPA 客户端
    ///
    /// 在实际项目中，建议将 OPA Client 封装为单例或注入到服务容器中，
    /// 并复用 `EventLoopGroup` 以获得最佳性能。
    @MainActor
    private func makeClient() -> (OPA, MultiThreadedEventLoopGroup) {
        // 1. 准备 EventLoopGroup
        // SwiftNIO 的核心组件。通常一个应用程序只需创建一个 Group，并在整个生命周期内复用。
        // 线程数通常设置为 `System.coreCount` 或者是 1 (对于简单客户端)。
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // 2. 准备 Logger
        // 使用 swift-log 进行日志记录。OPA Client 会输出请求/响应的详细调试信息。
        var logger = Logger(label: "opa-example")
        logger.logLevel = .info // 生产环境建议使用 .info 或 .error, 调试时使用 .debug
        
        // 3. 配置连接参数
        let connectionArg = OPA.ConnectionArgument(
            eventLoop: eventLoopGroup.next(), // 从 Group 中获取一个 EventLoop loop
            host: TestingShared.host,
            port: TestingShared.port,
            logger: logger
            // proxy: .server(host: "localhost", port: 9090) // 如果 OPA 支持 Proxy，可在此配置
        )
        
        // 4. 初始化 OPA 客户端
        // Client 初始化是轻量级的，建立了基本的配置映射。
        let opa = OPA(argument: connectionArg)
        
        return (opa, eventLoopGroup)
    }
    
    @Test("示例: 客户端的创建与销毁")
    @MainActor
    func exampleInitialize() async throws {
        // 获取客户端实例和线程组
        let (opa, eventLoopGroup) = makeClient()
        
        // 模拟使用客户端...
        print("OPA Client 已连接至: \(opa.argument.url)")
        #expect(opa.argument.port == TestingShared.port)
            
        // [重要] 资源清理
        // 在应用程序关闭时 (shutdown hook)，必须优雅地关闭 OPA Client 和 EventLoopGroup。
        // 1. `opa.shutdown()`: 释放 HTTP Client 连接池资源。
        // 2. `eventLoopGroup.shutdownGracefully()`: 关闭 IO 线程，清理未完成任务。
        
        // 使用 try? 确保即使清理过程中出现问题也不会掩盖业务逻辑错误
        try? await opa.shutdown()
        try? await eventLoopGroup.shutdownGracefully()
    }
    
    // MARK: - 2. 策略管理 (Policy Management)
    
    /// 演示如何上传(Deploy)、获取(Get)和删除(Delete) Rego 策略文件。
    @Test("示例: 策略的全生命周期管理")
    func examplePolicy() async throws {
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        // 使用 do-catch 确保即使中间步骤失败，finally 阶段也能执行资源清理
        do {
            let policyId = "example_policy.rego"
            
            // 2.1 定义 Rego 策略代码
            // OPA v1.0+ 引入了 `if` 关键字来明确规则体，推荐使用新语法。
            // 此规则含义：如果 input 中的 user 字段为 "admin"，则 allow 为 true。
            let regoCode = """
            package example.authz
            
            default allow = false
            
            allow if {
                input.user == "admin"
            }
            """
            
            // 2.2 上传/更新策略
            // API: PUT /v1/policies/<id>
            // 如果 ID 已存在则覆盖，否则创建。
            let saveResult = try await opa.policy.save(
                by: policyId,
                content: regoCode
            ).get() // .get() 将 EventLoopFuture 转换为 async 结果
            
            print("策略保存成功")
            // 结果通常是空的 Answer (Success)，如果没有抛出错误即表示成功。
            _ = saveResult.result
            
            // 2.3 获取策略内容
            // API: GET /v1/policies/<id>
            // 可以获取原始 Rego 代码，用于验证或审计。
            // 使用 AnyCodable 接收结果，或者使用 String.self 获取 raw content。
            if let policy = try await opa.policy.get(at: policyId, as: AnyCodable.self).result {
                print("获取到策略 ID: \(policy.id)")
            } else {
                Issue.record("错误: 刚刚保存的策略应当存在")
            }
            
            // 2.4 列出所有策略
            // API: GET /v1/policies
            let listResult = try await opa.policy.list(as: AnyCodable.self).get()
            print("当前服务器策略数量: \(listResult.result.count)")
            #expect(listResult.result.contains(where: { $0.id == policyId }))
            
            // 2.5 删除策略
            // API: DELETE /v1/policies/<id>
            let deleteResult = try await opa.policy.delete(of: policyId).get()
            print("策略删除成功")
            _ = deleteResult.result
            
        } catch {
            executionError = error
        }
        
        // 资源清理
        try? await opa.shutdown()
        try? await pool.shutdownGracefully()
        
        // 重新抛出业务逻辑中的错误，让测试显式失败
        if let error = executionError {
            throw error
        }
    }
    
    // MARK: - 3. 数据管理 (Data Management)
    
    /// 演示如何管理 OPA 中的 Base Documents (JSON 数据)。
    /// 这些数据通常是静态的或周期性更新的上下文数据 (例如用户角色列表、资源属性等)。
    @Test("示例: 数据的增删改查")
    func exampleData() async throws {
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        do {
            // OPA 中的数据路径。对应 Rego 中的 `data.users.bob`
            let dataPath = "/users/bob"
            
            // 定义 Swift 数据模型 (Codable)
            struct UserInfo: Codable, Sendable {
                let role: String
                let age: Int
            }
            
            // 3.1 上传/覆盖数据
            // API: PUT /v1/data/<path>
            let userInfo = UserInfo(role: "deployer", age: 30)
            let saveResult = try await opa.data.save(
                on: dataPath,
                data: userInfo
            ).get()
            
            print("数据保存成功")
            #expect(saveResult.result == true)
            
            // 3.2 获取数据
            // API: GET /v1/data/<path>
            // [Compatibility Note]: 某些 OPA 版本默认开启 strict-builtin-errors，可能导致查询非预期报错。
            // 这里显式设置 `strictBuiltinErrors: false` 以获得最大兼容性。
            if let fetchedData = try await opa.data.get(
                from: dataPath,
                as: UserInfo.self,
                parameter: .init(strictBuiltinErrors: false)
            ).result {
                print("获取到数据: role=\(fetchedData.role)")
                #expect(fetchedData.role == "deployer")
            } else {
                Issue.record("数据应当存在")
            }
            
            // 3.3 局部更新数据 (Patch)
            // API: PATCH /v1/data/<path>
            // 使用 JSON Patch (RFC 6902) 协议。推荐用于大文档的微小修改，减少网络传输。
            // 下例：将 role 字段的值修改为 "admin"
            let patchOps: [OPA.PatchOperation] = [
                .replace(path: "/role", value: AnyCodable("admin"))
            ]
            let patchResult = try await opa.data.patch(to: dataPath, operations: patchOps).get()
            print("数据更新成功")
            _ = patchResult.result
            
            // 验证更新结果
            let updatedData = try await opa.data.get(
                from: dataPath,
                as: UserInfo.self,
                parameter: .init(strictBuiltinErrors: false)
            ).get()
            #expect(updatedData.result?.role == "admin")
            
            // 3.4 删除数据
            // API: DELETE /v1/data/<path>
            let deleteResult = try await opa.data.delete(of: dataPath).get()
            print("数据删除成功")
            _ = deleteResult.result
            
        } catch {
            executionError = error
        }
        
        try? await opa.shutdown()
        try? await pool.shutdownGracefully()
        
        if let error = executionError {
            throw error
        }
    }
    
    // MARK: - 4. 决策查询 (Query)
    
    /// 演示如何向 OPA 发起决策请求。这是 SDK 最核心的功能。
    /// 包含 "Data Query" (推荐) 和 "Ad-hoc Query" 两种模式。
    @Test("示例: 执行权限查询")
    func exampleQuery() async throws {
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        do {
            // 准备: 上传一个简单的 ACL 策略
            // 规则: 仅当 role=="admin" 且 action=="read" 时，allow=true
            let policyId = "query_example.rego"
            let regoCode = """
            package query.example
            
            default allow = false
            
            allow if {
                input.role == "admin"
                input.action == "read"
            }
            """
            _ = try await opa.policy.save(by: policyId, content: regoCode).get()
            
            // 定义 Input 数据结构 (Client -> OPA)
            struct AccessRequest: Codable, Sendable {
                let role: String
                let action: String
            }
            
            // 4.1 Data Query (推荐生产环境使用)
            // 路径: /v1/data/<package>/<rule>
            // 特点: 直接查询已定义的规则结果。性能最好，语义最清晰。
            let input1 = AccessRequest(role: "admin", action: "read")
            
            let dataResult = try await opa.query.data(
                from: "/query/example/allow", // 对应 package query.example 中的 allow 规则
                input: input1,                // 传递给 OPA 的 input 全局变量
                as: Bool.self,                // 预期返回 Bool 类型 (allow 是 boolean)
                parameter: .init(strictBuiltinErrors: false)
            ).get()
            
            print("Data Query 结果: \(String(describing: dataResult.result))")
            #expect(dataResult.result == true)
            
            // 4.2 Ad-hoc Query (临时查询)
            // 路径: /v1/query
            // 特点: 可以在请求中发送任意 Rego 语句。灵活性高，但性能略低于 Data Query (因为需要实时解析部分 Rego)。
            // 适用于调试或动态构建复杂查询条件。
            let adhocQuery = "input.x * 2 > 10" // 一个简单的算术表达式
            let input3 = ["x": 6]               // context data
            
            let adhocResult = try await opa.query.adhoc(
                query: adhocQuery,
                input: input3,
                as: Bool.self
            ).get()
            
            print("Ad-hoc Query 结果 (Bool): \(String(describing: adhocResult.result))")
            
            // Ad-hoc 查询更通用的接收方式：使用 AnyCodable
            // 因为结果可能是一个 ResultSet (一组满足条件的变量绑定)
            let adhocRawResult = try await opa.query.adhoc(
                query: adhocQuery,
                input: input3,
                as: AnyCodable.self
            ).get()
            
            if let res = adhocRawResult.result {
                 print("Ad-hoc Query 结果 (Raw): \(res)")
            } else {
                 print("Ad-hoc Query 结果: nil")
            }
            
            // 清理测试用例创建的策略
            _ = try? await opa.policy.delete(of: policyId).get()
            
        } catch {
            executionError = error
        }
        
        try? await opa.shutdown()
        try? await pool.shutdownGracefully()
        
        if let error = executionError {
            throw error
        }
    }
    
    // MARK: - 5. 高级功能: 部分求值 (Partial Evaluation / Compile)
    
    /// 演示 Compile API 的使用。
    /// 部分求值允许你提供部分已知数据 (Input)，让 OPA 计算出剩余的逻辑条件。
    /// 这常用于将 OPA 策略转换为 SQL `WHERE` 子句等场景 (Data Filtering)。
    @Test("示例: 部分求值 (Compile)")
    func exampleCompile() async throws {
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        do {
            // 准备: 定义一个依赖 "外部资源属性" 的策略
            let policyId = "compile_example.rego"
            let regoCode = """
            package compile.example
            
            # 规则1: 管理员直接允许
            allow if {
                input.user == "admin"
            }
            
            # 规则2: 资源拥有者允许
            allow if {
                input.user == input.resource.owner
            }
            """
            _ = try await opa.policy.save(by: policyId, content: regoCode).get()
            
            // 场景假设:
            // 我们知道当前用户是 "bob"，但我们在做数据库查询之前，还不知道具体的 resource 信息。
            // 我们希望 OPA 告诉我们："对于 bob 来说，什么样的资源是允许访问的？"
            
            struct PartialInput: Codable, Sendable {
                let user: String
            }
            
            // 5.1 执行 Compile
            let input = PartialInput(user: "bob")
            // 声明 "input.resource" 是未知的 (Unknowns)
            let unknowns = ["input.resource"] 
            
            let partialResult = try await opa.compile.partial(
                query: "data.compile.example.allow == true", // 目标: allow 必须为 true
                input: input,
                unknowns: unknowns
            ).get()
            
            // 结果解析:
            // OPA 会返回一组简化后的 AST (Queries)。
            // 预期结果类似:
            // [[ref(eq) string("bob") ref(input.resource.owner)]]
            //
            // 解释:
            // 规则1 (admin) -> bob != admin -> False (被优化掉)
            // 规则2 (owner) -> bob == input.resource.owner -> 保留为剩余条件
            
            print("部分求值结果 (AST Queries): \(partialResult.result?.queries ?? [])")
            
            #expect(partialResult.result?.queries != nil)
            #expect(partialResult.result!.queries!.count > 0)
            
            // 清理
            _ = try? await opa.policy.delete(of: policyId).get()
            
        } catch {
            executionError = error
        }
        
        try? await opa.shutdown()
        try? await pool.shutdownGracefully()
        
        if let error = executionError {
            throw error
        }
    }
    
    // MARK: - 测试清理
    
    @MainActor
    @Test("结束测试清理")
    func end() async throws {
        // 确保全局共享的 OPA 实例也被正确关闭 (如果有)
        // 使用可选链调用，避免 crash
        try? TestingShared.opa?.syncShutdown()
    }
}
