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
        
        let datas = try await opa.data.list(as: [String: AnyCodable].self)
        #expect(datas.result.count == 0)
        
        let policies = try await opa.policy.list(as: [String: AnyCodable].self)
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
        @Sendable (OPA.Answer<OPA.CompileController.PartialResult>) throws -> Bool
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
    
    static let sqlDataFilterQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        OPA.CompileController.TargetDialect.SQL,
        OPA.CompileController.SQLTargetDataFilterOption,
        [String],
        @Sendable (OPA.Answer<OPA.CompileController.SQLTargetResult>) throws -> Bool
    )] = [
        (
            [],
            [(
                "testing",
                """
                package filters

                # METADATA
                # scope: document
                # compile:
                #   unknowns: [input.fruits]
                include if input.fruits.name == input.favorite

                include if {
                    input.fruits.name == "apple"
                    not input.favorite
                }
                """
            )],
            "/filters/include",
            ["favorite": "pineapple"],
            .postgresql,
            .init(),
            [],
            {
                $0.result.query == "WHERE fruits.name = E\'pineapple\'"
            }
        ),
        (
            [],
            [(
                "filter",
                """
                package filters

                # METADATA
                # scope: document
                # compile:
                #   unknowns: [input.fruits, input.price]
                include if input.fruits.name == input.favorite

                include if input.price == "free"
                """
            )],
            "/filters/include",
            ["favorite": "pineapple"],
            .postgresql,
            .init(
                tableMapping: [
                    "fruits": [
                        "$self": "fruit",
                        "name": "display_name",
                        "price": "price_tag"
                    ],
                    "price": [
                      "$table": "fruits"
                    ]
                ]
            ),
            ["input.fruits", "input.price"],
            {
                $0.result.query == "WHERE (fruit.display_name = E'pineapple' OR fruit.price_tag = E'free')"
            }
        ),
        (
            [],
            [(
                "authz",
                """
                package authz
                # METADATA
                # compile:
                #   unknowns: [input.users, input.subscriptions]
                
                # 此时 Rego 编译器会认为 users 和 subscriptions 是 input 的子项，是安全的
                allow if {
                    input.users.status == "active"
                    input.subscriptions.plan == input.required_plan
                }
                """
            )],
            "/authz/allow",
            ["required_plan": "premium"],
            .sqlite,
            .init(
                tableMapping: [
                    "users": [
                        "$self": "u",
                        "status": "user_status"
                    ],
                    "subscriptions": [
                        "$self": "s",
                        "plan": "plan_level"
                    ]
                ]
            ),
            ["input.users", "input.subscriptions"],
            {
                $0.result.query == "WHERE (u.user_status = 'active' AND s.plan_level = 'premium')"
            }
        )
    ]
    
    static let uCastDataFilterQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        OPA.CompileController.TargetDialect.UCAST,
        OPA.CompileController.UCASTTargetDataFilterOption,
        [String],
        @Sendable (OPA.Answer<OPA.CompileController.UCASTTargetResult>) throws -> Bool
    )] = [
        (
            [],
            [(
                "testing",
                """
                package filters

                # METADATA
                # scope: document
                # compile:
                #   unknowns: [input.fruits]
                include if input.fruits.name == input.favorite

                include if {
                    input.fruits.name == "apple"
                    not input.favorite
                }
                """
            )],
            "/filters/include",
            ["favorite": "pineapple"],
            .all,
            .init(),
            [],
            {
                $0.result.query == [
                    "field": "fruits.name",
                    "operator": "eq",
                    "type": "field",
                    "value": "pineapple"
                ]
            }
        ),
        (
            [],
            [(
                "authz",
                """
                package authz
                # METADATA
                # compile:
                #   unknowns: [input.users, input.subscriptions]
                
                # 此时 Rego 编译器会认为 users 和 subscriptions 是 input 的子项，是安全的
                allow if {
                    input.users.status == "active"
                    input.subscriptions.plan == input.required_plan
                }
                """
            )],
            "/authz/allow",
            ["required_plan": "premium"],
            .minimal,
            .init(),
            ["input.users", "input.subscriptions"],
            {
                $0.result.query == [
                    "operator": "and",
                    "type": "compound",
                    "value": [
                        [
                            "field": "users.status",
                            "operator": "eq",
                            "type": "field",
                            "value": "active"
                        ],
                        [
                            "field": "subscriptions.plan",
                            "operator": "eq",
                            "type": "field",
                            "value": "premium"
                        ]
                    ]
                ]
            }
        )
    ]
    
    static let multiDataFilterQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        OPA.CompileController.MultiTargetDataFilterOption,
        [String],
        @Sendable (OPA.Answer<OPA.CompileController.MultiTargetResult>) throws -> Bool
    )] = [
        (
            [],
            [(
                "testing",
                """
                package filters

                # METADATA
                # scope: document
                # compile:
                #   unknowns: [input.fruits]
                include if input.fruits.name == input.favorite

                include if {
                    input.fruits.name == "apple"
                    not input.favorite
                }
                """
            )],
            "/filters/include",
            ["favorite": "pineapple"],
            .init(
                targetDialects: [.sql(.postgresql), .sql(.sqlserver)]
            ),
            [],
            {
                try
                #require($0.result.postgresql?.query) == "WHERE fruits.name = E'pineapple'" &&
                #require($0.result.sqlserver?.query) == "WHERE fruits.name = N'pineapple'"
            }
        ),
        (
            [],
            [(
                "filter",
                """
                package filters

                # METADATA
                # scope: document
                # compile:
                #   unknowns: [input.fruits, input.price]
                include if input.fruits.name == input.favorite

                include if input.price == "free"
                """
            )],
            "/filters/include",
            ["favorite": "pineapple"],
            .init(
                targetDialects: [.sql(.mysql)],
                targetSQLTableMappings: [
                    .mysql: [
                        "fruits": [
                            "$self": "fruit",
                            "name": "display_name",
                            "price": "price_tag"
                        ],
                        "price": [
                          "$table": "fruits"
                        ]
                    ]
                ]
            ),
            ["input.fruits", "input.price"],
            {
                try #require($0.result.mysql?.query) == "WHERE (fruit.display_name = 'pineapple' OR fruit.price_tag = 'free')"
            }
        ),
        (
            [],
            [(
                "authz",
                """
                package authz
                # METADATA
                # compile:
                #   unknowns: [input.users, input.subscriptions]
                
                # 此时 Rego 编译器会认为 users 和 subscriptions 是 input 的子项，是安全的
                allow if {
                    input.users.status == "active"
                    input.subscriptions.plan == input.required_plan
                }
                """
            )],
            "/authz/allow",
            ["required_plan": "premium"],
            .init(
                targetDialects: [.sql(.sqlite), .ucast(.minimal)],
                targetSQLTableMappings: [
                    .sqlite: [
                        "users": [
                            "$self": "u",
                            "status": "user_status"
                        ],
                        "subscriptions": [
                            "$self": "s",
                            "plan": "plan_level"
                        ]
                    ]
                ]
            ),
            ["input.users", "input.subscriptions"],
            {
                try
                #require($0.result.sqlite?.query) == "WHERE (u.user_status = 'active' AND s.plan_level = 'premium')" &&
                #require($0.result.ucast?.query) == [
                    "operator": "and",
                    "type": "compound",
                    "value": [
                        [
                            "field": "users.status",
                            "operator": "eq",
                            "type": "field",
                            "value": "active"
                        ],
                        [
                            "field": "subscriptions.plan",
                            "operator": "eq",
                            "type": "field",
                            "value": "premium"
                        ]
                    ]
                ]
            }
        )
    ]
    
    @Test("Partial Query 测试", .serialized, arguments: partialQueries)
    func partialQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        query: String,
        input: DataType,
        options: OPA.CompileController.PartialOption,
        unknowns: [String],
        result: @Sendable (OPA.Answer<OPA.CompileController.PartialResult>) throws -> Bool
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await TestingShared.prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.compile.partial(
            query: query,
            input: input,
            options: options,
            unknowns: unknowns
        )
        #expect(try result(queryRes))
        
        for (name, key, value) in [(String, OPA.CompileController.QueryParameter, @Sendable (OPA.Answer<OPA.CompileController.PartialResult>) -> Bool)](
            arrayLiteral:
            ("pretty 测试", .init(pretty: true), { _ in true }),
            ("explain 测试", .init(explain: .full), { _ in true }),
            ("metrics 测试", .init(metrics: true), { $0.metrics != nil }),
            ("instrument 测试", .init(instrument: true), {
                $0.metrics?.histogramEvalOpPlug != nil &&
                $0.metrics?.histogramPartialOpSaveSetContains != nil
            })
        ) {
            let dataOutput = try await opa.compile.partial(
                query: query,
                input: input,
                options: options,
                unknowns: unknowns,
                parameter: key
            )
            
            #expect(try result(dataOutput), .init(stringLiteral: name))
            #expect(dataOutput.warnings == nil, .init(stringLiteral: name))
            #expect(value(dataOutput), .init(stringLiteral: name))
        }
        
        try await TestingShared.clean(policies: policies)
    }
    
    @Test("SQL Target Data Filter Query 测试", .serialized, arguments: sqlDataFilterQueries)
    func sqlDataFilterQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        path: String,
        input: DataType,
        target: OPA.CompileController.TargetDialect.SQL,
        options: OPA.CompileController.SQLTargetDataFilterOption,
        unknowns: [String],
        result: @Sendable (OPA.Answer<OPA.CompileController.SQLTargetResult>) throws -> Bool
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await TestingShared.prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.compile.sqlDataFilter(
            path: path,
            input: input,
            target: target,
            options: options,
            unknowns: unknowns
        )
        #expect(try result(queryRes))
        
        for (name, key, value) in [(String, OPA.CompileController.QueryParameter, @Sendable (OPA.Answer<OPA.CompileController.SQLTargetResult>) -> Bool)](
            arrayLiteral:
            ("pretty 测试", .init(pretty: true), { _ in true }),
            ("explain 测试", .init(explain: .full), { _ in true }),
            ("metrics 测试", .init(metrics: true), { $0.metrics != nil }),
            ("instrument 测试", .init(instrument: true), {
                $0.metrics?.timerCompileEvalConstraints != nil &&
                $0.metrics?.timerCompilePrepPartial != nil &&
                $0.metrics?.timerCompileTranslateQueries != nil
            })
        ) {
            let dataOutput = try await opa.compile.sqlDataFilter(
                path: path,
                input: input,
                target: target,
                options: options,
                unknowns: unknowns,
                parameter: key
            )
            
            #expect(try result(dataOutput), .init(stringLiteral: name))
            #expect(dataOutput.warnings == nil, .init(stringLiteral: name))
            #expect(value(dataOutput), .init(stringLiteral: name))
        }
        
        try await TestingShared.clean(policies: policies)
    }
    
    @Test("UCAST Target Data Filter Query 测试", .serialized, arguments: uCastDataFilterQueries)
    func uCastDataFilterQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        path: String,
        input: DataType,
        target: OPA.CompileController.TargetDialect.UCAST,
        options: OPA.CompileController.UCASTTargetDataFilterOption,
        unknowns: [String],
        result: @Sendable (OPA.Answer<OPA.CompileController.UCASTTargetResult>) throws -> Bool
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await TestingShared.prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.compile.uCastDataFilter(
            path: path,
            input: input,
            target: target,
            options: options,
            unknowns: unknowns
        )
        #expect(try result(queryRes))
        
        for (name, key, value) in [(String, OPA.CompileController.QueryParameter, @Sendable (OPA.Answer<OPA.CompileController.UCASTTargetResult>) -> Bool)](
            arrayLiteral:
            ("pretty 测试", .init(pretty: true), { _ in true }),
            ("explain 测试", .init(explain: .full), { _ in true }),
            ("metrics 测试", .init(metrics: true), { $0.metrics != nil }),
            ("instrument 测试", .init(instrument: true), { $0.metrics != nil })
        ) {
            let dataOutput = try await opa.compile.uCastDataFilter(
                path: path,
                input: input,
                target: target,
                options: options,
                unknowns: unknowns,
                parameter: key
            )
            
            #expect(try result(dataOutput), .init(stringLiteral: name))
            #expect(dataOutput.warnings == nil, .init(stringLiteral: name))
            #expect(value(dataOutput), .init(stringLiteral: name))
        }
        
        try await TestingShared.clean(policies: policies)
    }
    
    @Test("Multi Target Data Filter Query 测试", .serialized, arguments: multiDataFilterQueries)
    func multiDataFilterQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        path: String,
        input: DataType,
        options: OPA.CompileController.MultiTargetDataFilterOption,
        unknowns: [String],
        result: @Sendable (OPA.Answer<OPA.CompileController.MultiTargetResult>) throws -> Bool
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await TestingShared.prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.compile.dataFilter(
            path: path,
            input: input,
            options: options,
            unknowns: unknowns
        )
        #expect(try result(queryRes))
        
        for (name, key, value) in [(String, OPA.CompileController.QueryParameter, @Sendable (OPA.Answer<OPA.CompileController.MultiTargetResult>) -> Bool)](
            arrayLiteral:
            ("pretty 测试", .init(pretty: true), { _ in true }),
            ("explain 测试", .init(explain: .full), { _ in true }),
            ("metrics 测试", .init(metrics: true), { $0.metrics != nil }),
            ("instrument 测试", .init(instrument: true), { $0.metrics != nil })
        ) {
            let dataOutput = try await opa.compile.dataFilter(
                path: path,
                input: input,
                options: options,
                unknowns: unknowns,
                parameter: key
            )
            
            #expect(try result(dataOutput), .init(stringLiteral: name))
            #expect(dataOutput.warnings == nil, .init(stringLiteral: name))
            #expect(value(dataOutput), .init(stringLiteral: name))
        }
        
        try await TestingShared.clean(policies: policies)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .extra
    }
}
