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

        print(res)

    }

    @MainActor
    @Test("测试结束")
    func end() async throws {
        try? TestingShared.opa?.syncShutdown()
        TestingShared.opa = nil
        TestingShared.testStage = .examples
    }
}
