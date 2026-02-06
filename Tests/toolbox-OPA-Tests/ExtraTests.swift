import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
@testable import OPA
@preconcurrency import AnyCodable

@Suite("OPA 补充测试集", .serialized, .enabled(if: TestingShared.opaListening))
struct OPAExtraTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .extra {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    @Test func test1() async throws {
        let opa = try await TestingShared.getOPA()
        
        try await opa.policy.save(by: "id_test_001", content: """
        package rules.id_1001
        allow if {
            input.resource.owner.name == input.user.name
            input.action == "read"
        }    
        """)

        try await opa.policy.save(by: "id_test_002", content: """
        package rules.id_1002
        allow if {
            input.resource.lvl >= 5
            input.action == "write"
        }   
        """)

        try await opa.policy.save(by: "authz", content: """
        package authz

        import data.rules

        allow if {
            some rule_id
            current_rule := rules[rule_id]
            current_rule.allow == true
        }  
        """)

        let res = try await opa.query.data(
            from: "/id_test_002/allow",
            input: [
                "action": AnyCodable("write"),
                "resource": [
                    "owner": [
                        "name": "clwang"
                    ],
                    "lvl": 10
                ]
            ],
            as: AnyCodable.self
        )

        #expect(res.result == nil)

        let ans = try await opa.query.data(
            from: "/rules/id_1002/allow",
            input: [
                "action": AnyCodable("write"),
                "resource": [
                    "owner": [
                        "name": "clwang"
                    ],
                    "lvl": 10
                ]
            ],
            as: AnyCodable.self
        )
        
        #expect(ans.result == true)
        
        let ans2 = try await opa.query.data(
            from: "/rules/id_1002/allow",
            input: [
                "action": AnyCodable("write"),
                "resource": [
                    "owner": [
                        "name": "clwang"
                    ],
                    "lvl": 4
                ]
            ],
            as: AnyCodable.self
        )
        
        #expect(ans2.result == nil)
        
        try await clean()
    }
    
    @Test("Test2")
    func test2() async throws {
        let opa = try await TestingShared.getOPA()
        
        try await opa.policy.save(by: "id_test_001", content: """
        package rules.id_1001
        allow if {
            input.resource.owner.name == input.user.name
            input.action == "read"
        }
        """)
        
        try await opa.policy.save(by: "id_test_002", content: """
        package rules.id_1002
        allow if {
            input.resource.lvl >= 5
            input.action == "write"
        }
        """)
        
        try await opa.policy.save(by: "authz", content: """
        package authz
        
        import data.rules
        
        check if {
            current_rule := rules[_]
            current_rule == input.rules[_]
            current_rule.allow == input.allow
        }
        """)
        
        let sqlRes = try await opa.compile.sqlDataFilter(
            path: "/authz/check",
            input: [
                "resource": AnyCodable([
                    "owner": [
                        "name": "clwang"
                    ],
                    "lvl": 10,
                ]),
                "input.action": "write",
                "allow": true
            ],
            target: .postgresql,
            unknowns: ["input.rules"]
        )
        
        let h = try #require(sqlRes.hints)
        #expect(!h.isEmpty)

        try await clean()
    }
    
    @Test("清理")
    func finalClean() async throws {
        try await clean()
    }

    func clean() async throws {
        let opa = try await TestingShared.getOPA()
        
        let policies = try await opa.policy.list(as: AnyCodable.self)
        
        let policyPairs = policies.result.map { ($0.id, $0.raw) }

        try await TestingShared.clean(policies: policyPairs)
        
        let data = try await opa.data.list(as: [String: AnyCodable].self)
        try await emptyAll(data: data.result)
        
        func emptyAll(data: [String: AnyCodable]) async throws {
            for (k, _) in data {
                try await opa.data.delete(of: "/" + k)
            }
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        try? TestingShared.opa?.syncShutdown()
        TestingShared.opa = nil
        TestingShared.testStage = .examples
    }
}
