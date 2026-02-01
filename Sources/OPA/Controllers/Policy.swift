import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle

public extension OPA {
    final class PolicyController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }
        
        public func save(
            by id: String,
            content: String
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                method: .PUT,
                body: content,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).map { _ in }
        }
        
        public func delete(
            of id: String
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                method: .DELETE,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - delete \(id)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).map { _ in }
        }
        
        public struct PolicyResult<T: Decodable & Sendable>: Decodable, Sendable {
            let id: String
            let raw: String
            let ast: T
        }
        
        public func get<T: Decodable & Sendable>(
            at id: String,
            as type: T.Type = T.self,
            pretty: Bool = false
        ) -> EventLoopRes<PolicyResult<T>?, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                queries: [URLQueryItem(name: "pretty", value: String(pretty))],
                method: .GET,
                validStatusCode: [.ok, .notFound],
                errorStatusCode: [
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                if res.status == .notFound {
                    return nil
                }
                
                let wrapped = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: PolicyResult<T>.self)) 失败", category: .internal) {
                    try res.json(as: SingleResult<PolicyResult<T>>.self).get()
                }
                return wrapped.result
            }
        }
        
        public func list<T: Decodable & Sendable>(
            as type: T.Type = T.self
        ) -> EventLoopRes<[PolicyResult<T>], Errcase> {
            send(
                uri: "/v1/policies",
                method: .GET,
                errorStatusCode: [
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let wrapped = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: PolicyResult<T>.self)) 失败", category: .internal) {
                    try res.json(as: SingleResult<[PolicyResult<T>]>.self).get()
                }
                return wrapped.result ?? []
            }
        }
    }
}
