import NIOCore
import NIOAdvanced
@preconcurrency import AnyCodable

public extension OPA {
    final class QueryController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }
        
        public func simple<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            input: G
        ) -> EventLoopRes<T, Errcase> {
            send(
                uri: "/",
                method: .POST,
                body: input
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try res.json().get()
            }
        }
        
        public func adhoc<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            query: String,
            input: G
        ) -> EventLoopRes<T, Errcase> {
            send(
                uri: "/v1/query",
                method: .POST,
                body: [
                    "query": AnyCodable(query),
                    "input": AnyCodable(input)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try res.json().get()
            }
        }
    }
}
