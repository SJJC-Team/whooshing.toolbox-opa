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
    
    typealias DataType = TestingShared.DataType
    
    static let partialQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        OPA.PartialOption,
        [String],
        AnyCodable
    )] = [
        
    ]
    
    @Test("Partial Query 测试", .serialized, arguments: partialQueries)
    func partialQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        query: String,
        input: DataType,
        options: OPA.PartialOption,
        unknowns: [String],
        result: AnyCodable
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await TestingShared.prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.compile.partial(
            query: query,
            input: input,
            options: options,
            unknowns: unknowns,
            as: AnyCodable.self
        ).get()
        #expect(queryRes == result)
        
        try await TestingShared.clean(policies: policies)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        try! TestingShared.opa!.syncShutdown().get()
    }
}

