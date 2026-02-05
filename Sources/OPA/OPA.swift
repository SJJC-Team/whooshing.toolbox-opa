import ErrorHandle
import NIOCore
import Logging
import LoggingAdvanced
import NIOAdvanced
import AsyncHTTPClient

/// Open Policy Agent (OPA) 客户端
///
/// `OPA` 类是与 Open Policy Agent 服务器进行交互的主要入口点。
/// 它封装了 HTTP 客户端，并提供了对 OPA 各个功能模块（Policy, Data, Query, Compile）的访问控制器。
///
/// 使用示例：
/// ```swift
/// let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
/// let logger = Logger(label: "opa-client")
///
/// let connectionArg = OPA.ConnectionArgument(
///     eventLoop: eventLoopGroup.next(),
///     host: "localhost",
///     port: 8181,
///     logger: logger
/// )
///
/// let opa = OPA(argument: connectionArg)
/// ```
public final class OPA: Sendable {
    
    /// 连接参数配置，包含 Host, Port, EventLoop 等信息
    public let argument: ConnectionArgument
    
    /// 策略控制器
    ///
    ///用于管理 Policy Modules (.rego 文件)，提供增删改查功能。
    public let policy: PolicyController
    
    /// 数据控制器
    ///
    /// 用于管理 Base Documents (JSON 数据)，提供增删改查功能。
    public let data: DataController
    
    /// 查询控制器
    ///
    /// 用于执行 Rego 查询，支持 Simple Query, Data Query 和 Ad-hoc Query。
    public let query: QueryController
    
    /// 编译控制器
    ///
    /// 用于执行 Compile API 操作，例如部分求值 (Partial Evaluation) 和数据过滤 (Data Filtering)。
    public let compile: CompileController
    
    var logger: Logger { argument.logger }
    
    /// 初始化 OPA 客户端
    ///
    /// - Parameter argument: 连接参数配置对象 `ConnectionArgument`
    public init(
        argument: ConnectionArgument
    ) {
        self.argument = argument
        self.policy = PolicyController(argument: argument, logger: argument.logger.derive(subId: "policy"))
        self.data = DataController(argument: argument, logger: argument.logger.derive(subId: "data"))
        self.query = QueryController(argument: argument, logger: argument.logger.derive(subId: "query"))
        self.compile = CompileController(argument: argument, logger: argument.logger.derive(subId: "compile"))
        logger.info("OPA Client 创建成功", metadata: argument.metadata)
    }
    
    /// 同步关闭客户端
    ///
    /// 释放 HTTP 客户端资源。应在程序退出前调用。
    public func syncShutdown() throws(Errcase.ErrType) {
        try logger.required(throws: Errcase.shutdownFailed, category: .internal) {
            try argument.client.syncShutdown()
        }
        
        logger.info("OPA Client 关闭成功", metadata: argument.metadata)
    }
    
    /// 异步关闭客户端 (Async/Await)
    public func shutdown() async throws(Errcase.ErrType) {
        try await logger.required(throws: Errcase.shutdownFailed, category: .internal) {
            try await argument.client.shutdown()
        }
        
        logger.info("OPA Client 关闭成功", metadata: argument.metadata)
    }
    
    /// 异步关闭客户端 (EventLoopFuture)
    public func shutdown() -> EventLoopRes<Void, Errcase> {
        argument.client.shutdown()
            .withError(Errcase.shutdownFailed, category: .internal, logger: logger)
            .flatMap
        {
            self.logger.info("OPA Client 关闭成功", metadata: self.argument.metadata)
            return self.argument.eventLoop.makeSucceededVoidResult()
        }
    }
}

public extension OPA {
    /// OPA 连接参数
    struct ConnectionArgument: Sendable {
        /// HTTP 请求协议类型 (HTTP/HTTPS)
        public let scheme: Scheme
        /// OPA 服务器主机地址
        public let host: String
        /// OPA 服务器端口
        public let port: Int
        /// 用于处理请求的 EventLoop
        public let eventLoop: EventLoop
        
        let client: HTTPClient
        let logger: Logger
        
        /// HTTP 请求协议类型 (HTTP/HTTPS)
        public enum Scheme: String, Sendable {
            case http
            case https
        }
        
        /// 初始化连接参数
        ///
        /// - Parameters:
        ///   - eventLoop: EventLoop 实例
        ///   - scheme: HTTP 请求协议类型 (HTTP/HTTPS)
        ///   - host: 主机名 (例如 "localhost")
        ///   - port: 端口号 (例如 8181)
        ///   - logger: Logger 实例
        ///   - proxy: 可选的 HTTP 代理配置
        public init(
            eventLoop: EventLoop,
            scheme: Scheme = .http,
            host: String = "localhost",
            port: Int = 8181,
            logger: Logger,
            proxy: HTTPClient.Configuration.Proxy? = nil
        ) {
            self.scheme = scheme
            self.host = host
            self.port = port
            self.eventLoop = eventLoop
            self.logger = logger
            self.client = HTTPClient(
                eventLoopGroup: eventLoop,
                configuration: .init(
                    timeout: .init(connect: .seconds(30)),
                    proxy: proxy, decompression: .enabled(limit: .none)
                ),
                backgroundActivityLogger: logger.derive(subId: "http.client.background")
            )
        }
        
        var url: String {
            "\(scheme)://\(host):\(port)"
        }
        
        var metadata: Logger.Metadata {
            ["url": .string(url), "eventLoop": .id(eventLoop)]
        }
    }
}
