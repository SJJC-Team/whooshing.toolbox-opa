import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
@testable import OPA
@preconcurrency import AnyCodable

@Suite("OPA 测试集", .serialized, .enabled(if: TestingShared.opaListening))
struct OPATesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .basic {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test func t() async throws {
        let opa = await TestingShared.getOPA()
        
        let data: [String: AnyCodable] = [
            "name": "clwang",
            "age": 25
        ]
        
        let r = try await opa.data.save(path: "/testing/helloworld", ifNoneMatch: nil, data: data).get()
        
        print(r)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .basic
        try! TestingShared.opa!.syncShutdown().get()
    }
}
