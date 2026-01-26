import NIOCore
import NIOAdvanced
import Foundation
@preconcurrency import AnyCodable

public extension OPA {
    final class DataController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }
        
        public func save<T: Encodable & Sendable>(
            path: String,
            ifNoneMatch: String? = "*",
            data: T
        ) -> EventLoopRes<Bool, Errcase> {
            send(
                uri: "/v1/data" + path,
                method: .PUT,
                extraHeaders: ifNoneMatch == nil ? [:] : [
                    "If-None-Match": ifNoneMatch!
                ],
                body: data,
                validStatusCode: [.noContent, .notModified]
            ).map { res in
                if res.status == .notModified {
                    return false
                }
                return true
            }
        }
        
        public func delete(
            path: String
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/data" + path,
                method: .DELETE,
                validStatusCode: [.noContent]
            ).map { _ in }
        }
        
        public func patch<T: Encodable & Sendable>(
            path: String,
            data: T
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/data" + path,
                method: .PATCH,
                extraHeaders: [
                    "Content-Type": "application/json-patch+json"
                ],
                body: data,
                validStatusCode: [.noContent]
            ).map { _ in }
        }
        
        public func get<T: Encodable & Sendable, G: Decodable & Sendable>(
            path: String,
            input: T? = nil,
            pretty: Bool = false,
            provenance: Bool = false
        ) -> EventLoopRes<G?, Errcase> {
            send(
                uri: "/v1/data" + path,
                queries: [
                    URLQueryItem(name: "pretty", value: String(pretty)),
                    URLQueryItem(name: "provenance", value: String(provenance))
                ],
                method: .POST,
                body: [
                    "input" : AnyCodable(input)
                ],
                validStatusCode: [.ok, .notFound]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                if res.status == .notFound {
                    return nil
                }
                
                return try res.json().get()
            }
        }
    }
}
