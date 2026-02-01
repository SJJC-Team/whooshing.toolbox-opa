import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
@testable import OPA
@preconcurrency import AnyCodable

@Suite("OPA Query 测试集", .serialized, .enabled(if: TestingShared.opaListening))
struct OPAQueryTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .query {
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
    
    typealias DataType = [String: AnyCodable]
    
    static let simpleQueries: [(
        [(String, DataType)],
        [(String, String)],
        DataType,
        AnyCodable
    )] = [
        // 样例 1：基础权限决策 (RBAC)
        // 逻辑：如果用户是管理员，则 allow 为 true
        (
            [],
            [
                (
                    "example1",
                    """
                    package system

                    main := msg if {
                        msg := sprintf("hello, %v", [input.user])
                    }
                    """
                )
            ],
            ["user": "alice"],
            "hello, alice"
        ),

        // 样例 2：动态属性过滤 (ABAC)
        // 逻辑：根据用户年龄判断是否允许进入
        (
            [
                ("/settings", ["min_age": 18])
            ],
            [
                (
                    "age_check",
                    """
                    package system
                    
                    main := true if {
                        input.age >= data.settings.min_age
                    }
                    """
                )
            ],
            ["age": 20],
            true
        ),

        // 样例 3：复杂数据转换与投影
        // 逻辑：从原始服务器数据中，根据 input 过滤出特定协议的服务器 ID
        (
            [
                ("/infrastructure/servers", [
                    "s1": ["protocol": "https", "status": "active"],
                    "s2": ["protocol": "http", "status": "active"]
                ])
            ],
            [
                ("filter_logic", """
                package system
                
                main contains id if {
                    some id
                    server := data.infrastructure.servers[id]
                    server.protocol == input.required_proto
                    server.status == "active"
                }
                """)
            ],
            ["required_proto": AnyCodable("https")],
            ["s1"]
        )
    ]
    
    static let dataQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        AnyCodable
    )] = [
        // 样例 1：简单的权限判定 (返回 Boolean)
        (
            datas: [("/users/list", ["alice": ["role": "admin"]])],
            policies: [("auth", """
                package app.auth
            
                allow if data.users.list[input.user].role == "admin"
            """)],
            path: "/app/auth/allow",
            input: ["user": AnyCodable("alice")],
            result: AnyCodable(true)
        ),

        // 样例 2：数据结构投影 (返回 Object)
        (
            datas: [("/inventory/items", ["p1": ["name": "MacBook", "price": 1299]])],
            policies: [("shop", """
                package app.shop
                item_info := data.inventory.items[input.item_id]
            """)],
            path: "/app/shop/item_info",
            input: ["item_id": AnyCodable("p1")],
            result: AnyCodable(["name": "MacBook", "price": 1299])
        ),

        // 样例 3：集合推导式 (返回 Array)
        (
            datas: [("/logs/events", [
                ["id": AnyCodable(1), "level": AnyCodable("error")],
                ["id": AnyCodable(2), "level": AnyCodable("info")],
                ["id": AnyCodable(3), "level": AnyCodable("error")]
            ])],
            policies: [("monitor", """
                package app.monitor
                errors contains id if {
                    some event in data.logs.events
                    event.level == "error"
                    id := event.id
                }
            """)],
            path: "/app/monitor/errors",
            input: [:],
            result: AnyCodable([1, 3])
        )
    ]
    
    static let adhocQueries: [(
        [(String, AnyCodable)],
        [(String, String)],
        String,
        DataType,
        AnyCodable
    )] = [
        // 样例 1：跨路径数据 Join (无需在 Policy 预定义)
        // 逻辑：找出在 users 和 roles 中 ID 匹配且角色为 admin 的用户名
        (
            datas: [
                ("/users", AnyCodable([["id": 1, "name": "alice"], ["id": 2, "name": "bob"]])),
                ("/roles", AnyCodable([["u_id": 1, "role": "admin"]]))
            ],
            policies: [],
            query: "data.users[i].id == data.roles[j].u_id; data.roles[j].role == \"admin\"; username := data.users[i].name",
            input: [:],
            result: AnyCodable([["i": 0, "j": 0, "username": "alice"]])
        ),

        // 样例 2：结合 Policy 规则进行动态计算
        // 逻辑：调用 Policy 里的基础规则，并在此基础上做 ad-hoc 的逻辑追加
        (
            datas: [("/base_price", AnyCodable(100))],
            policies: [("math_lib", "package lib.math \n tax := 0.1")],
            query: "final_price := data.base_price * (1 + data.lib.math.tax)",
            input: [:],
            result: AnyCodable([["final_price": 110]])
        ),

        // 样例 3：基于 Input 的条件筛选
        // 逻辑：检查 input 中的用户是否在 data 的白名单中
        (
            datas: [("/whitelist", AnyCodable(["alice", "charlie"]))],
            policies: [],
            query: "data.whitelist[_] == input.user",
            input: ["user": AnyCodable("alice")],
            result: AnyCodable([[:]])
        ),
        
        (
            datas: [("/whitelist", AnyCodable(["alice", "charlie"]))],
            policies: [],
            query: "data.whitelist[_] == input.user",
            input: ["user": AnyCodable("not_exist")],
            result: AnyCodable([:])
        )
    ]
    
    @Test("OPA Simple 查询测试", .serialized, arguments: simpleQueries)
    func opaSimpleQuery(
        datas: [(String, DataType)],
        policies: [(String, String)],
        input: DataType,
        result: AnyCodable
    ) async throws {
        let opa = try await TestingShared.getOPA()

        try await prepare(datas: datas.map { ($0.0, AnyCodable($0.1)) }, policies: policies)
        
        let queryRes = try await opa.query.simple(input: input, as: AnyCodable.self).get()
        #expect(queryRes == result)
        
        try await clean(policies: policies)
    }
    
    @Test("OPA Data 查询测试", .serialized, arguments: dataQueries)
    func opaDataQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        path: String,
        input: DataType,
        result: AnyCodable
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.query.data(from: path, input: input, as: AnyCodable.self).get()
        #expect(queryRes == result)
        
        try await clean(policies: policies)
    }

    @Test("OPA adhoc 查询测试", .serialized, arguments: adhocQueries)
    func opaAdhocQuery(
        datas: [(String, AnyCodable)],
        policies: [(String, String)],
        query: String,
        input: DataType,
        result: AnyCodable
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        try await prepare(datas: datas, policies: policies)
        
        let queryRes = try await opa.query.adhoc(query: query, input: input, as: AnyCodable.self).get()
        #expect(queryRes == result)
        
        try await clean(policies: policies)
    }
    
    func prepare(
        datas: [(String, AnyCodable)],
        policies: [(String, String)]
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        for data in datas {
            let res = try await opa.data.save(on: data.0, data: data.1).get()
            #expect(res == true)
        }
        
        for policy in policies {
            try await opa.policy.save(by: policy.0, content: policy.1).get()
        }
    }
    
    func clean(
        policies: [(String, String)]
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        for policy in policies {
            try await opa.policy.delete(of: policy.0).get()
        }
        
        let datas = try await opa.data.list(as: DataType.self).get()
        for (k, _) in datas {
            try await opa.data.delete(of: "/" + k).get()
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .compile
    }
}

