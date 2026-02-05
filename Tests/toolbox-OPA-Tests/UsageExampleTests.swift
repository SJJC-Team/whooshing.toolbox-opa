import Testing
import NIOCore
import NIOPosix
import Foundation
import Logging
import LoggingAdvanced
@testable import OPA
@preconcurrency import AnyCodable

/// OPA 使用示例测试集
///
/// 包含用于文档 README 的标准使用示例代码。
/// 每个测试用例都模拟了真实场景下的 API 调用流程。
@Suite("OPA 使用示例", .serialized, .enabled(if: TestingShared.opaListening))
struct UsageExampleTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .examples {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    /// 获取测试用 OPA 实例 (模拟真实环境初始化)
    @MainActor
    private func makeClient() -> (OPA, MultiThreadedEventLoopGroup) {
        // 1. 准备 EventLoopGroup
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // 2. 准备 Logger
        var logger = Logger(label: "opa-example")
        logger.logLevel = .info
        
        // 3. 配置连接参数
        let connectionArg = OPA.ConnectionArgument(
            eventLoop: eventLoopGroup.next(),
            host: TestingShared.host,
            port: TestingShared.port,
            logger: logger,
            proxy: .server(host: "localhost", port: 9090)
        )
        
        // 4. 初始化 OPA 客户端
        let opa = OPA(argument: connectionArg)
        
        return (opa, eventLoopGroup)
    }
    
    @Test("客户端初始化示例")
    @MainActor
    func exampleInitialize() async throws {
        // 1. 准备 EventLoopGroup (通常在一个应用中只需创建一个)
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // 2. 准备 Logger
        var logger = Logger(label: "opa-client-example")
        logger.logLevel = .info
        
        // 3. 配置连接参数
        let connectionArg = OPA.ConnectionArgument(
            eventLoop: eventLoopGroup.next(), // 从 Group 中获取一个 EventLoop
            host: TestingShared.host,         // OPA 服务器地址 (例如 "localhost")
            port: TestingShared.port,         // OPA 服务器端口 (例如 8181)
            logger: logger,
            proxy: .server(host: "localhost", port: 9090)   // 中间代理，可用于抓包工具进行流量 debug, 也可置 nil，即不设代理
        )
        
        // 4. 初始化 OPA 客户端
        let opa = OPA(argument: connectionArg)
        
        defer {
            // 注意: 在应用退出前，务必关闭客户端，否则会造成断言导致崩溃
            try? opa.syncShutdown()
        }
        
        // 验证: 打印一些信息证明创建成功
        print("OPA Client created: \(opa.argument.url)")
        #expect(opa.argument.port == TestingShared.port)
    }
    
    @Test("策略 (Policy) 管理示例")
    func examplePolicy() async throws {
        // 初始化客户端
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        do {
            let policyId = "example_policy.rego"
            
            // 1. 定义策略内容 (Rego 代码)
            // OPA v1.0+ 推荐使用 `if` 关键字
            let regoCode = """
            package example.authz
            
            default allow = false
            
            allow if {
                input.user == "admin"
            }
            """
            
            // 2. 保存 (创建或更新) 策略
            // 使用 PUT /v1/policies/<id>
            let saveResult = try await opa.policy.save(
                by: policyId,
                content: regoCode
            ).get()
            
            print("策略保存成功")
            _ = saveResult.result
            
            // 3. 获取策略
            // 使用 GET /v1/policies/<id>
            if let policy = try await opa.policy.get(at: policyId, as: AnyCodable.self).get() {
                print("获取到策略: \(policy.result.id)")
            } else {
                Issue.record("策略应当存在")
            }
            
            // 4. 列出所有策略
            // 使用 GET /v1/policies
            let listResult = try await opa.policy.list(as: AnyCodable.self).get()
            print("当前策略数量: \(listResult.result.count)")
            #expect(listResult.result.contains(where: { $0.id == policyId }))
            
            // 5. 删除策略
            // 使用 DELETE /v1/policies/<id>
            let deleteResult = try await opa.policy.delete(of: policyId).get()
            print("策略删除成功")
            _ = deleteResult.result
            
        } catch {
            executionError = error
        }
        
        // 清理资源 (确保总是执行)
        try? await opa.shutdown()
        try? await pool.shutdownGracefully()
        
        // 如果有错误，抛出
        if let error = executionError {
            throw error
        }
    }
    
    @Test("数据 (Data) 管理示例")
    func exampleData() async throws {
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        do {
            let dataPath = "/users/bob" // 注意路径以 / 开头，对应 OPA 中的 data.users.bob
            
            // 定义数据模型
            struct UserInfo: Codable, Sendable {
                let role: String
                let age: Int
            }
            
            // 1. 保存 (创建或覆盖) 数据
            // 使用 PUT /v1/data/<path>
            let userInfo = UserInfo(role: "deployer", age: 30)
            let saveResult = try await opa.data.save(
                on: dataPath,
                data: userInfo
            ).get()
            
            print("数据保存成功")
            #expect(saveResult.result == true)
            
            // 2. 获取数据
            // 使用 GET /v1/data/<path>
            // 显式设置 strictBuiltinErrors: false (Get 支持此参数)
            if let fetchedData = try await opa.data.get(
                from: dataPath,
                as: UserInfo.self,
                parameter: .init(strictBuiltinErrors: false)
            ).get() {
                print("获取到数据: role=\(fetchedData.result.role)")
                #expect(fetchedData.result.role == "deployer")
            } else {
                Issue.record("数据应当存在")
            }
            
            // 3. 更新数据 (Patch)
            // 使用 PATCH /v1/data/<path>
            // 将 role 修改为 "admin"
            let patchOps: [OPA.PatchOperation] = [
                .replace(path: "/role", value: AnyCodable("admin"))
            ]
            let patchResult = try await opa.data.patch(to: dataPath, operations: patchOps).get()
            print("数据更新成功")
            _ = patchResult.result
            
            // 验证更新
            let updatedData = try await opa.data.get(from: dataPath, as: UserInfo.self, parameter: .init(strictBuiltinErrors: false)).get()
            #expect(updatedData?.result.role == "admin")
            
            // 4. 删除数据
            // 使用 DELETE /v1/data/<path>
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
    
    @Test("查询 (Query) 示例")
    func exampleQuery() async throws {
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        do {
            // 准备工作: 上传一个策略
            // 该策略表示仅有所输入的角色(role) 为 "admin"， 且动作(action) 为 "read"
            // 才可访问，否则一律拒绝
            let policyId = "query_example.rego"
            let regoCode = """
            package query.example
            
            default allow = false
            
            # OPA v1.0+ 语法
            allow if {
                input.role == "admin"
                input.action == "read"
            }
            """
            // 将该策略上传到 OPA 中
            try await opa.policy.save(by: policyId, content: regoCode)
            
            // 定义输入数据结构
            struct AccessRequest: Codable, Sendable {
                let role: String
                let action: String
            }
            
            // 1. Data Query (推荐)
            let input1 = AccessRequest(role: "admin", action: "read")
            
            let dataResult = try await opa.query.data(
                from: "/query/example/allow",
                input: input1,
                as: Bool.self, 
                parameter: .init(strictBuiltinErrors: false)
            ).get()
            
            print("Data Query 结果: \(String(describing: dataResult?.result))")
            #expect(dataResult?.result == true)
            
            // 2. Ad-hoc Query (临时查询)
            let adhocQuery = "input.x * 2 > 10"
            let input3 = ["x": 6]
            
            let adhocResult = try await opa.query.adhoc(
                query: adhocQuery,
                input: input3,
                as: Bool.self
            ).get()
            
            print("Ad-hoc Query 结果: \(String(describing: adhocResult.result))")
            
            let adhocRawResult = try await opa.query.adhoc(
                query: adhocQuery,
                input: input3,
                as: AnyCodable.self
            ).get()
            
            if let res = adhocRawResult.result {
                 print("Ad-hoc Raw Result: \(res)")
            } else {
                 print("Ad-hoc Raw Result: nil")
            }
            
            // 清理策略
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
    
    @Test("编译 (Compile) 示例 - 部分求值")
    func exampleCompile() async throws {
        let (opa, pool) = await makeClient()
        var executionError: Error?
        
        do {
            // 准备工作: 策略
            let policyId = "compile_example.rego"
            let regoCode = """
            package compile.example
            
            allow if {
                input.user == "admin"
            }
            
            allow if {
                input.user == input.resource.owner
            }
            """
            _ = try await opa.policy.save(by: policyId, content: regoCode).get()
            
            // 场景: 我们知道当前用户是 "bob"，但不知道资源的所有者是谁 (resource.owner 未知)
            // 我们希望 OPA 只有根据已知条件进行简化，返回剩余的逻辑
            
            struct PartialInput: Codable, Sendable {
                let user: String
            }
            
            // 1. 执行部分求值 (Partial Evaluation)
            let input = PartialInput(user: "bob")
            let unknowns = ["input.resource"] // 指定哪些部分是未知的
            
            let partialResult = try await opa.compile.partial(
                query: "data.compile.example.allow == true",
                input: input,
                unknowns: unknowns
            ).get()
            
            // [[[ref(eq) string("bob") ref(input.resource.owner)]]]
            // 表示若 bob = input.resource.owner, 其便是该资源的所有者
            // 尽管看上去该逻辑无用，但这只是简单的逻辑判断，复杂逻辑下这就非常有用了
            print("部分求值结果 (queries): \(partialResult.result.queries ?? [])")
            
            #expect(partialResult.result.queries != nil)
            
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
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        try! TestingShared.opa!.syncShutdown()
    }
}
