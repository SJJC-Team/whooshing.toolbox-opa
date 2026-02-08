import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
@testable import OPA
@preconcurrency import AnyCodable

@Suite("OPA Policy 测试集", .serialized, .enabled(if: TestingShared.opaListening))
struct OPAPolicyTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .policy {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let policyList: [(String, String)] = [
        // 1. 你的原始示例：复杂关联查询 (Data-to-Data Join)
        (
            "networks_check",
            """
            package opa.examples
            import data.networks
            import data.ports
            import data.servers

            public_servers contains server if {
                server := servers[_]
                server.ports[_] == ports[k].id
                ports[k].networks[_] == networks[m].id
                networks[m].public == true
            }
            """
        ),

        // 2. 基础 RBAC 决策：依赖 input 的虚拟文档
        (
            "rbac_allow",
            """
            package app.rbac
            
            default allow = false
            
            # 当用户是 admin 时允许
            allow if {
                input.user == "admin"
            }
            
            # 当用户拥有特定角色时允许
            allow if {
                user_roles := data.user_roles[input.user]
                user_roles[_] == "editor"
                input.action == "read"
            }
            """
        ),

        // 3. 数据转换：将数组转换为以 ID 为 Key 的字典
        (
            "data_transform",
            """
            package transform
            
            # 动态生成一个虚拟文档，重组数据结构
            user_map[user.id] = user if {
                user := data.users[_]
            }
            """
        ),

        // 4. 辅助函数：Rego 中的函数定义
        (
            "utils",
            """
            package lib.utils
            
            # 定义一个函数用来判断是否为内网 IP
            is_internal(ip) if {
                startswith(ip, "192.168.")
            }
            
            is_internal(ip) if {
                startswith(ip, "10.")
            }
            """
        )
    ]
    
    @Test("Policy 创建测试", arguments: policyList)
    func policyCreating(id: String, content: String) async throws {
        let opa = try await TestingShared.getOPA()
        
        let metrics = Bool.random()
        let pretty = Bool.random()
        let res = try await opa.policy.save(by: id, content: content, parameter: .init(pretty: pretty, metrics: metrics))
        if metrics {
            #expect(res.metrics != nil)
        }
        
        let r = try #require(try await opa.policy.get(at: id, as: [String: AnyCodable].self).result)
        
        #expect(content == r.raw)
    }
    
    @Test("Policy 创建失败测试")
    func policyCreateFail() async throws {
        let opa = try await TestingShared.getOPA()
        
        let content = """
        package opa.examples

        import data.networks
        import data.ports
        import data.servers

        public_servers contains server if {
            some k, m
            server := servers[_]
            server.ports[_] == ports[k].id
            ports[k].networks[_] == networks[m].id
            networks[m].public == tr
        }    
        """
        let metrics = Bool.random()
        let pretty = Bool.random()
        await #expect(throws: OPA.Errcase.ErrType.self) {
            try await opa.policy.save(by: "testing_id", content: content, parameter: .init(pretty: pretty, metrics: metrics))
        }
    }
    
    @Test("Policy List 测试")
    func policyListTest() async throws {
        let opa = try await TestingShared.getOPA()
        
        let res = try await opa.policy.list(as: [String: AnyCodable].self)
        
        #expect(res.result.count == Self.policyList.count)
        #expect(res.result.allSatisfy { r in Self.policyList.contains { $0.1 == r.raw && $0.0 == r.id } })
    }

    static var policyIds: [String] {
        policyList.map { $0.0 }
    }
    
    @Test("Policy Delete 测试", arguments: policyIds)
    func policyDelete(id: String) async throws {
        let opa = try await TestingShared.getOPA()
        
        let parameter = OPA.PolicyController.DeleteQueryParameter(
            pretty: .random(),
            metrics: .random()
        )
        let deleteRes = try await opa.policy.delete(of: id, parameter: parameter)
        if parameter.metrics {
            #expect(deleteRes.metrics != nil)
        }
        
        let res = try await opa.policy.get(at: id, as: [String: AnyCodable].self)
        #expect(res.result == nil)
    }
    
    @Test("Policy 应当为空")
    func policyShouldBeEmpty() async throws {
        let opa = try await TestingShared.getOPA()
        
        let list = try await opa.policy.list(as: [String: AnyCodable].self)
        #expect(list.result.count == 0)
    }
    
    @Test("Not Found 测试")
    func notFound() async throws {
        let opa = try await TestingShared.getOPA()
        
        let res = try await opa.policy.get(at: "the_id_doesn_t_exist", as: AnyCodable.self)
        #expect(res.result == nil)
    }
    
    @Test("Policy Check 测试")
    func policyCheck() async throws {
        let opa = try await TestingShared.getOPA()
        
        let result = try await opa.policy.check(policy: "input.servers[i].ports[_] = \"p2\"; input.servers[i].name = name")
        
        switch result {
        case .success(let r): print(r)
        case .failure: #expect(Bool(false))
        }
        
        let result2 = try await opa.policy.check(policy: "input.servers[1i].ports[_] = \"p2\"; input.servers[i].name = name")
        
        switch result2 {
        case .success: #expect(Bool(false))
        case .failure(let error): #expect(error.errors != nil)
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        try! await TestingShared.opa!.shutdown().get()
        TestingShared.opa = nil
        TestingShared.testStage = .query
    }
}
