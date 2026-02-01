import ErrorHandle
import NIOCore
import Logging
import NIOAdvanced
import AsyncHTTPClient

public final class OPA: Sendable {
    
    public let argument: ConnectionArgument
    public let policy: PolicyController
    public let data: DataController
    public let query: QueryController
    public let compile: CompileController
    
    public init(
        argument: ConnectionArgument
    ) {
        self.argument = argument
        self.policy = PolicyController(argument: argument)
        self.data = DataController(argument: argument)
        self.query = QueryController(argument: argument)
        self.compile = CompileController(argument: argument)
    }
    
    public func syncShutdown() -> Res<Void, Errcase> {
        .init(throws: .shutdownFailed, category: .internal) {
            try argument.client.syncShutdown()
        }
    }
    
    public func shutdown() async -> Res<Void, Errcase> {
        await .async(throws: .shutdownFailed, category: .internal) {
            try await argument.client.shutdown()
        }
    }
    
    public func shutdown() -> EventLoopRes<Void, Errcase> {
        argument.client.shutdown().withError(Errcase.shutdownFailed, category: .internal)
    }
    
    public struct ConnectionArgument: Sendable {
        let client: HTTPClient
        public let host: String
        public let port: Int
        public let eventLoop: EventLoop
        public let logger: Logger
        
        init(
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
