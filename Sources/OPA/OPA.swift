import ErrorHandle
import NIOCore
import Logging
import NIOAdvanced
import AsyncHTTPClient

/// OPA 客户端
///
/// 用于与 Open Policy Agent 服务器进行交互的主要入口类。
/// 提供了对 Policy, Data, Query 和 Compile API 的访问控制器。
///
/// 准备 OPA 客户端实例：
public final class OPA: Sendable {
    
    /// 连接参数
    public let argument: ConnectionArgument
    
    /// 策略控制器: 管理 Policy Modules (.rego 文件)
    public let policy: PolicyController
    /// 数据控制器: 管理 Base Documents (JSON 数据)
    public let data: DataController
    /// 查询控制器: 执行 Rego 查询
    public let query: QueryController
    /// 编译控制器: 执行部分求值和编译
    public let compile: CompileController
    
    /// 初始化 OPA 客户端
    /// - Parameter argument: 连接参数
    public init(
        argument: ConnectionArgument
    ) {
        self.argument = argument
        self.policy = PolicyController(argument: argument)
        self.data = DataController(argument: argument)
        self.query = QueryController(argument: argument)
        self.compile = CompileController(argument: argument)
    }
    
        /// 同步关闭客户端
        ///
        /// 释放 HTTP 客户端资源。应在程序退出前调用。
        public func syncShutdown() throws(Errcase.ErrType) {
            try required(throws: Errcase.shutdownFailed, category: .internal) {
                try argument.client.syncShutdown()
            }
        }
        
        /// 异步关闭客户端 (Async/Await)
        public func shutdown() async throws(Errcase.ErrType) {
            try await required(throws: Errcase.shutdownFailed, category: .internal) {
                try await argument.client.shutdown()
            }
        }
        
        /// 异步关闭客户端 (EventLoopFuture)
        public func shutdown() -> EventLoopRes<Void, Errcase> {
            argument.client.shutdown().withError(Errcase.shutdownFailed, category: .internal)
        }
    
    /// OPA 连接参数
    public struct ConnectionArgument: Sendable {
        let client: HTTPClient
        /// OPA 服务器主机地址
        public let host: String
        /// OPA 服务器端口
        public let port: Int
        /// 用于处理请求的 EventLoop
        public let eventLoop: EventLoop
        /// 日志记录器
        public let logger: Logger
        
        /// 初始化连接参数
        ///
        /// - Parameters:
        ///   - host: 主机名 (例如 "localhost")
        ///   - port: 端口号 (例如 8181)
        ///   - eventLoop: EventLoop 实例
        ///   - logger: Logger 实例
        ///   - proxy: 可选的 HTTP 代理配置
        public init(
            host: String,
            port: Int,
            eventLoop: EventLoop,
            logger: Logger,
            proxy: HTTPClient.Configuration.Proxy? = nil
        ) {
            self.host = host
            self.port = port
            self.eventLoop = eventLoop
            self.logger = logger
            self.client = HTTPClient(
                eventLoopGroup: eventLoop,
                configuration: .init(proxy: proxy, decompression: .enabled(limit: .ratio(10)))
            )
        }
        
        var url: String {
            "http://\(host):\(port)"
        }
    }
}
