import NIOCore
import NIOAdvanced
import Foundation

public extension OPA {
    final class PolicyController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }
        
        public func save(
            id: String,
            content: String
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                method: .PUT,
                body: content
            ).map { _ in }
        }
        
        public func delete(
            id: String
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                method: .DELETE
            ).map { _ in }
        }
        
        public func get<T: Decodable & Sendable>(
            id: String,
            pretty: Bool = false
        ) -> EventLoopRes<T?, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                queries: [URLQueryItem(name: "pretty", value: String(pretty))],
                method: .GET,
                validStatusCode: [.ok, .notFound]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                if res.status == .notFound {
                    return nil
                }
                
                let wrapped: SingleResult<T> = try res.json().get()
                return wrapped.result
            }
        }
        
        public func list<T: Decodable & Sendable>() -> EventLoopRes<[T], Errcase> {
            send(
                uri: "/v1/policies",
                method: .GET
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let wrapped: SingleResult<[T]> = try res.json().get()
                return wrapped.result ?? []
            }
        }
    }
}
