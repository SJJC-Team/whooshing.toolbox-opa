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
        #expect(datas.result.count == 0)
        
        let policies = try await opa.policy.list(as: [String: AnyCodable].self).get()
        #expect(policies.result.count == 0)
    }
    
    typealias DataType = TestingShared.DataType
    
    static let partialQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        OPA.CompileController.PartialOption,
        [String],
        @Sendable (OPA.Answer<OPA.CompileController.PartialResultBlock>) throws -> Bool
    )] = [
        // 1. Deterministic Success (True) -> 结果应为 queries: [[]]
        (
            [], [], "x = 1; y = 2; x < y", [:], .init(), [],
            {
                $0.result.description == """
                [ref(eq) var("x") number(1)] AND [ref(eq) var("y") number(2)]
                """
            }
        ),
        
        // 2. Deterministic Failure (False) -> 结果应为 queries: []
        (
            [], [], "x = 1; y = 2; x > y", [:], .init(), [],
            {
                $0.result.description == "always false"
            }
        ),
        
        // 3. Data Dependency -> 即使有外部数据，能算出来的也应该是 True
        (
            [("/fixed/data", AnyCodable(["value": 42]))],
            [],
            "data.fixed.data.value == 42",
            [:],
            .init(),
            [],
            {
                $0.result.description == "always true"
            }
        ),
        
        // 4. Basic Unknown (Residual) -> 检查是否包含残余表达式 "input.x > 10"
        (
            [], [], "input.x > 10", [:], .init(), ["input.x"],
            {
                $0.result.description == "[ref(gt) ref(input.x) number(10)]"
            }
        ),
        
        // 5. Transitive/Inlining policy -> 检查是否正确内联并保留了 input.x 的判断
        (
            [],
            [("test.rego", "package test\np if { input.x == 100 }")],
            "data.test.p",
            [:],
            .init(),
            ["input.x"],
            {
                $0.result.description == "[ref(eq) ref(input.x) number(100)]"
            }
        )
    ]
    
    static let dataFilterQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        OPA.CompileController.DataFilterOption,
        [String],
        @Sendable (OPA.Answer<DataType>) throws -> Bool
    )] = [
        
    ]
    
    @Test("Partial Query 测试", .serialized, arguments: partialQueries)
    func partialQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        query: String,
        input: DataType,
        options: OPA.CompileController.PartialOption,
        unknowns: [String],
        result: @Sendable (OPA.Answer<OPA.CompileController.PartialResultBlock>) throws -> Bool
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await TestingShared.prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.compile.partial(
            query: query,
            input: input,
            options: options,
            unknowns: unknowns
        ).get()
        #expect(try result(queryRes))
        
        try await TestingShared.clean(policies: policies)
    }
    
    @Test("Data Filter Query 测试", .serialized, arguments: dataFilterQueries)
    func dataFilterQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        path: String,
        input: DataType,
        options: OPA.CompileController.DataFilterOption,
        unknowns: [String],
        result: @Sendable (OPA.Answer<DataType>) throws -> Bool
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await TestingShared.prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.compile.dataFilter(
            path: path,
            input: input,
            options: options,
            unknowns: unknowns,
            as: DataType.self
        ).get()
        #expect(try result(queryRes))
        
        try await TestingShared.clean(policies: policies)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        try! TestingShared.opa!.syncShutdown().get()
    }
}

