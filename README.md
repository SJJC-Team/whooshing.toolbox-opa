# whooshing.toolbox-opa
Whooshing 项目的访问控制模块，依赖 OPA 提供极细且高度自定义的权限设定





准备 OPA 客户端实例：

``` swift
// 准备线程，该实例将运行在其上
let pool = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let logger = Logger(label: "Testing")

// 创建一个 OPA 客户端实例，可以通过该实例对 OPA 服务进行操作
let opa = OPA(argument: .init(
    host: "localhost",
    port: 8181,
    eventLoop: pool.next(),
    logger: logger
))

// ...

// 所有任务完成后，务必执行 shutdown 函数，否则引发泄漏会导致断言崩溃
try? opa.syncShutdown().get()
```

对 OPA 服务的 Data 进行操作，可对其中的数据进行 增 删 改 查 操作：

