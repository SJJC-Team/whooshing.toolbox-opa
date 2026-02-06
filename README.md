# Whooshing OPA 依赖库

> [!NOTE]
> 本项目核心依赖于 **[Open Policy Agent (OPA)](https://github.com/open-policy-agent/opa)**。
> 特别感谢 OPA 团队创造了如此出色且强大的策略引擎，为本项目的实现提供了坚实基础。

本项目为 [Whooshing](https://github.com/SJJC-Team/whooshing) 系统的 **OPA (Open Policy Agent) 依赖库**，旨在为 Swift 后端服务提供强类型的 OPA 交互能力。封装了 Policy 管理、Data 上下文维护以及高效的决策查询接口，全面支持 Swift Concurrency (Async/Await)。本库底层严格遵循并封装了 **[OPA REST API](https://www.openpolicyagent.org/docs/latest/rest-api/)**。

### 特性

- **全面并发支持**：基于 `SwiftNIO` 和 `Async/Await` 构建，完美契合现代 Swift 服务端生态。
- **强类型接口**：利用 `Codable` 实现 Swift 结构体与 OPA JSON 数据的无缝转换，避免手动解析的繁琐与风险。
- **完整生命周期管理**：支持 Rego 策略文件的增删改查 (CRUD) 以及 Base Documents (Data) 的动态维护。
- **多种查询模式**：支持高性能的 Data Query、灵活的 Ad-hoc Query 以及高级的 Partial Evaluation (部分求值)。
- **错误处理友好**：提供结构化的错误类型，自动处理 OPA HTTP 响应状态码。

----------

### 导入该依赖库

在你的 `Package.swift` 加入：

```swift
.package(url: "https://github.com/SJJC-Team/whooshing.toolbox-opa", from: "1.0.0")
```

在依赖模块中引入:

```swift
.product(name: "OPA", package: "whooshing.toolbox-opa")
```

在需要的地方:

```swift
import OPA
```

--------

### 使用介绍

#### 1. 客户端初始化

要创建一个 `OPA` 客户端实例，你需要准备 `EventLoopGroup` 和连接参数 `ConnectionArgument`。

```swift
import OPA
import NIOCore
import NIOPosix
import Logging

// 1. 准备线程组 (通常整个应用复用一个 Group)
let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

// 2. 准备连接参数
let connectionArg = OPA.ConnectionArgument(
    eventLoop: eventLoopGroup.next(), // 选择一个 EventLoop
    host: "localhost",                // OPA 服务地址
    port: 8181,                       // OPA 服务端口
    logger: Logger(label: "opa-client")
)

// 3. 初始化客户端
let opa = OPA(argument: connectionArg)

// ... 使用 opa 进行操作 ...

// [重要] 应用退出时释放资源
try await opa.shutdown()
try await eventLoopGroup.shutdownGracefully()
```

#### 2. 策略管理 (Policy Management)

支持对 Rego 策略文件的上传、获取、列出和删除。

**上传策略:**

```swift
let policyId = "example.rego"
// OPA v1.0+ 推荐使用 `if` 关键字
let regoCode = """
package example.authz
default allow = false
allow if {
    input.user == "admin"
}
"""

// 保存策略 (若存在则覆盖)
try await opa.policy.save(by: policyId, content: regoCode).get()
```

**获取与列出:**

```swift
// 获取指定策略内容
if let policy = try await opa.policy.get(at: policyId, as: String.self).get() {
    print("Policy ID: \(policy.result.id)")
}

// 列出所有策略
let list = try await opa.policy.list(as: AnyCodable.self).get()
print("Total policies: \(list.result.count)")
```

#### 3. 数据管理 (Data Management)

动态管理 OPA 的上下文数据 (`base documents`)。

```swift
// 定义数据模型
struct UserInfo: Codable {
    let role: String
    let age: Int
}

let dataPath = "/users/bob" // 对应 Rego 中的 data.users.bob

// 保存数据
let userInfo = UserInfo(role: "deployer", age: 30)
try await opa.data.save(on: dataPath, data: userInfo).get()

// 获取数据 (建议显式关闭 strict-builtin-errors 以提高兼容性)
if let fetched = try await opa.data.get(
    from: dataPath, 
    as: UserInfo.self, 
    parameter: .init(strictBuiltinErrors: false)
).get() {
    print("Role: \(fetched.result.role)")
}

// 局部更新 (Patch)
let patchOps: [OPA.PatchOperation] = [
    .replace(path: "/role", value: AnyCodable("admin"))
]
try await opa.data.patch(to: dataPath, operations: patchOps).get()
```

#### 4. 决策查询 (Query)

SDK 提供了多种查询方式，其中 **Data Query** 是最推荐的生产环境用法。

**Data Query (推荐):**

直接查询已定义的规则路径，语义清晰且性能最佳。

```swift
struct AccessRequest: Codable {
    let role: String
    let action: String
}

let input = AccessRequest(role: "admin", action: "read")

// 查询 data.example.authz.allow 规则
// 假设规则返回布尔值
let allowed = try await opa.query.data(
    from: "/example/authz/allow",
    input: input,
    as: Bool.self,
    parameter: .init(strictBuiltinErrors: false)
).get()

if allowed.result == true {
    print("Access Granted")
}
```

**Ad-hoc Query (临时查询):**

发送任意 Rego 语句进行计算，适合调试或复杂动态场景。

```swift
// 计算一个数学表达式
let result = try await opa.query.adhoc(
    query: "input.x * 2 > 10",
    input: ["x": 6],
    as: Bool.self
).get()
```

#### 5. 高级功能: 部分求值 (Compile)

Compile API 允许你提供部分已知数据 (`Unknowns`)，让 OPA 返回简化后的 AST 条件。这常用于 Data Filtering 场景 (如将 OPA 策略转换为 SQL WHERE 子句)。

```swift
struct PartialInput: Codable {
    let user: String
}

let input = PartialInput(user: "bob")
// 告诉 OPA 我们还不知道 resource 信息
let unknowns = ["input.resource"] 

let partialResult = try await opa.compile.partial(
    query: "data.example.authz.allow == true",
    input: input,
    unknowns: unknowns
).get()

// 返回简化后的查询条件 AST
print(partialResult.result.queries)
```

-------

### 运行环境

* **macOS** (> 11.0)
* **iOS** (> 14.0)
* **Linux** (> 20)
* **Swift** (> 6.0)
* **watchOS** (> 6.0) **[未测试]**
* **tvOS**(> 13) **[未测试]**

-------

### OPA 参考资源

- **[OPA 文档](https://www.openpolicyagent.org/docs)**: OPA 的官方文档，包含详细的概念介绍和使用指南。
- **[Rego 语言参考](https://www.openpolicyagent.org/docs/policy-language)**: Rego 策略语言的语法和内置函数参考。
- **[OPA 生态系统](https://www.openpolicyagent.org/ecosystem)**: 了解 OPA 的各种集成和工具。
- **[OPA Playground](https://play.openpolicyagent.org/)**: 在线编写和测试 Rego 策略的实验环境。

-------

### 注意事项

- **资源管理**: 请确保正确管理 OPA Client 和 EventLoopGroup 的生命周期，避免资源泄漏。
- **路径规范**: OPA Data API 的路径通常以 `/` 开头，例如 `/users/alice`。
- **并发安全**: `OPA` 客户端是线程安全的 (`Sendable`)，可以在多 Task 中共享使用。

如需了解更多，请参阅各模块内的源码注释与文档说明。

------

### 联系与反馈

如有使用问题或建议，请通过 [GitHub Issues](https://github.com/SJJC-Team/whooshing.toolbox-opa/issues) 提交反馈。

或发至邮箱 [contact@official.whooshings.space](mailto:contact@official.whooshings.space)
