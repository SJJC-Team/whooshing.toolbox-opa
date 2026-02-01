import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
@testable import OPA
@preconcurrency import AnyCodable

@Suite("OPA Compile 测试集", .serialized, .enabled(if: TestingShared.opaListening))
struct OPACompileTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .compile {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("Env Prepare")
    func envPrepare() async throws {
        let opa = try await TestingShared.getOPA()
        
        let datas = try await opa.data.list(as: [String: AnyCodable].self).get()
        #expect(datas.count == 0)
        
        let policies = try await opa.policy.list(as: [String: AnyCodable].self).get()
        #expect(policies.count == 0)
    }
    
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        try! TestingShared.opa!.syncShutdown().get()
    }
}

