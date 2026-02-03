import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
@testable import OPA
@preconcurrency import AnyCodable

@Suite("OPA Data 测试集", .serialized, .enabled(if: TestingShared.opaListening))
struct OPADataTesting {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .data {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    static let dataList: [(String, [String: AnyCodable])] = [
        // 1. 简单键值对
        ("/v1/var", ["env": AnyCodable("dev"), "debug": AnyCodable(true)]),
        
        // 2. 包含数值
        ("/v1/sensor/config", ["threshold": AnyCodable(10.5), "active": AnyCodable(1)]),
        
        // 3. 嵌套字典 (模拟导航配置)
        ("/navigation/settings", [
            "params": AnyCodable(["gain": 0.8, "offset": 2.0]),
            "mode": AnyCodable("auto")
        ]),
        
        // 4. 包含数组 (模拟日志或端口)
        ("/device/status", [
            "logs": AnyCodable(["boot_ok", "wifi_connected"]),
            "ports": AnyCodable([80, 443])
        ]),
        
        // 5. 深度嵌套 (模拟复杂的 Policy Data)
        ("/admin_01", [
            "profile": AnyCodable([
                "roles": ["admin", "developer"],
                "metadata": ["last_login": 1706274617]
            ]),
            "enabled": AnyCodable(true)
        ])
    ]
    
    static let patchList: [(String, [String: AnyCodable], [OPA.PatchOperation], String, [String: AnyCodable]?)] = [
        // 1. 基础 Add：在根部添加新字段
        (
            "/v1/vars",
            ["env": AnyCodable("dev"), "debug": AnyCodable(true)],
            [.add(path: "/Testing", value: AnyCodable("helloworld!"))],
            "/v1/vars",
            ["env": AnyCodable("dev"), "debug": AnyCodable(true), "Testing": AnyCodable("helloworld!")]
        ),
        
        // 2. Replace：修改现有字段的值
        (
            "/v1/config",
            ["status": AnyCodable("offline"), "retry": AnyCodable(3)],
            [.replace(path: "/status", value: AnyCodable("online"))],
            "/v1/config",
            ["status": AnyCodable("online"), "retry": AnyCodable(3)]
        ),
        
        // 3. Remove：删除特定字段
        (
            "/v1/cache",
            ["temp_id": AnyCodable("123"), "persistent": AnyCodable(false)],
            [.remove(path: "/temp_id")],
            "/v1/cache",
            ["persistent": AnyCodable(false)]
        ),
        
        // 4. Test + Multiple Ops：先校验版本，再执行更新 (原子性测试)
        (
            "/v1/app",
            ["version": AnyCodable(1), "data": AnyCodable("old")],
            [
                .replace(path: "/data", value: AnyCodable("new")),
                .add(path: "/updated", value: AnyCodable(true))
            ],
            "/v1/app",
            ["version": AnyCodable(1), "data": AnyCodable("new"), "updated": AnyCodable(true)]
        ),
        
        // 5. Array Append：使用 "/-" 向数组末尾追加元素
        (
            "/v1/tags",
            ["list": AnyCodable(["swift", "nio"])],
            [.add(path: "/list/-", value: AnyCodable("opa"))],
            "/v1/tags",
            ["list": AnyCodable(["swift", "nio", "opa"])]
        )
    ]
    
    static let patchList2: [(String, [String: AnyCodable], [OPA.PatchOperation], String, [String: AnyCodable]?)] = [
        // 6. 深度嵌套的 Add (自动创建中间层级)
        // 这里的 path 是相对于 /v1/system 的，所以会创建 /v1/system/network/proxy/enabled
        (
            "/v1/system",
            ["mode": AnyCodable("standalone")],
            [.add(path: "/network", value: AnyCodable(["proxy": ["enabled": true]]))],
            "/v1/system",
            ["mode": AnyCodable("standalone"), "network": AnyCodable(["proxy": ["enabled": true]])]
        ),

        // 7. 数组索引操作 (在指定位置插入)
        // 初始是 [A, B]，在索引 1 插入 X，预期变成 [A, X, B]
        (
            "/v1/workflow",
            ["steps": AnyCodable(["start", "end"])],
            [.add(path: "/steps/1", value: AnyCodable("process"))],
            "/v1/workflow",
            ["steps": AnyCodable(["start", "process", "end"])]
        ),

        // 8. 多重 Test 保护 (只有当多个条件满足时才执行删除和替换)
        (
            "/v1/security",
            [
                "level": AnyCodable(3),
                "locked": AnyCodable(false),
                "temp_key": AnyCodable("tmp-99")
            ],
            [
                .replace(path: "/level", value: AnyCodable(4)),
                .remove(path: "/temp_key")
            ],
            "/v1/security",
            ["level": AnyCodable(4), "locked": AnyCodable(false)]
        ),

        // 9. 数组元素替换 (修改数组中的特定项)
        // 将数组中的第二个元素 (索引 1) 从 "guest" 替换为 "member"
        (
            "/v1/groups",
            ["users": AnyCodable(["admin", "guest", "anonymous"])],
            [.replace(path: "/users/1", value: AnyCodable("member"))],
            "/v1/groups",
            ["users": AnyCodable(["admin", "member", "anonymous"])]
        )
    ]
    
    @Test("Data 创建测试", arguments: dataList)
    func dataCreating(path: String, data: [String: AnyCodable]) async throws {
        let opa = try await TestingShared.getOPA()
        
        var res = try await opa.data.save(on: path, ifNoneMatch: nil, data: data)
        #expect(res == true)
        
        let dataOutput = try #require(try await opa.data.get(from: path, as: [String: AnyCodable].self))
        #expect(data == dataOutput.result)
        #expect(dataOutput.warnings == nil)
        
        // 尝试覆盖，应当失败
        res = try await opa.data.save(on: path, data: data)
        #expect(res == false)
        
        // 再次尝试覆盖，应当成功
        res = try await opa.data.save(on: path, ifNoneMatch: nil, data: data)
        #expect(res == true)
    }
    
    @Test("Patch 测试 1", .serialized, arguments: patchList)
    func dataPatching(
        path: String,
        data: [String: AnyCodable],
        patchOperation: [OPA.PatchOperation],
        pathNew: String,
        dataNew: [String: AnyCodable]?
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        let res = try await opa.data.save(on: path, ifNoneMatch: nil, data: data)
        #expect(res == true)
        
        try await opa.data.patch(to: path, operations: patchOperation)
        
        let dataTest = try #require(try await opa.data.get(from: pathNew, as: [String: AnyCodable].self))
        #expect(dataNew == dataTest.result)
        #expect(dataTest.warnings == nil)
    }
    
    @Test("Patch 测试 2", .serialized, arguments: patchList2)
    func dataPatching2(
        path: String,
        data: [String: AnyCodable],
        patchOperation: [OPA.PatchOperation],
        pathNew: String,
        dataNew: [String: AnyCodable]?
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        let res = try await opa.data.save(on: path, ifNoneMatch: nil, data: data)
        #expect(res == true)
        
        try await opa.data.patch(to: path, operations: patchOperation)
        
        let dataTest = try #require(try await opa.data.get(from: pathNew, as: [String: AnyCodable].self))
        #expect(dataNew == dataTest.result)
        #expect(dataTest.warnings == nil)
    }
    
    @Test("Delete 测试", .serialized, arguments:
        dataList.map { ($0.0, $0.1 as [String: AnyCodable]?) } +
        patchList.map { ($0.3, $0.4) } +
        patchList2.map { ($0.3, $0.4) }
    )
    func dataDelete(path: String, data: [String: AnyCodable]?) async throws {
        let opa = try await TestingShared.getOPA()
        
        let d = try await opa.data.get(from: path, as: [String: AnyCodable].self)
        #expect(d?.result == data)
        
        try await opa.data.delete(of: path)
    }
    
    @Test("Not Found 测试")
    func notFound() async throws {
        let opa = try await TestingShared.getOPA()
        
        let res = try await opa.data.get(from: "/the/path/doesn/t/exist", as: [String: AnyCodable].self)
        #expect(res == nil)
    }
    
    @Test("Data 应当为空")
    func dataShouldBeEmpty() async throws {
        let opa = try await TestingShared.getOPA()
        
        let data = try await opa.data.list(as: [String: AnyCodable].self)
        #expect(isEmpty(items: data.result))
        
        try await emptyAll(data: data.result)
        
        let res = try await opa.data.list(as: [String: AnyCodable].self)
        #expect(res.result.count == 0)
        
        func emptyAll(data: [String: AnyCodable]) async throws {
            for (k, _) in data {
                try await opa.data.delete(of: "/" + k)
            }
        }
        
        func isEmpty(items: [String: Any]?) -> Bool {
            guard let res = items else {
                return true
            }
            
            for (_, v) in res {
                if let a = v as? AnyCodable {
                    guard let d = a.value as? [String: Any]? else {
                        return false
                    }
                    
                    guard isEmpty(items: d) == true else {
                        return false
                    }
                } else if let d = v as? [String: Any]? {
                    guard isEmpty(items: d) else {
                        return false
                    }
                } else {
                    return false
                }
            }
            
            return true
        }
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .policy
    }
}
