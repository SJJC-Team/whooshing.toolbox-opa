import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public extension OPA {
    final class DataController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }
        
        public func save<T: Encodable & Sendable>(
            on path: String,
            ifNoneMatch: String? = "*",
            data: T,
            parameter: SaveQueryParameter = .init()
        ) -> EventLoopRes<Bool, Errcase> {
            send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
                method: .PUT,
                extraHeaders: ifNoneMatch == nil ? [:] : [
                    "If-None-Match": ifNoneMatch!
                ],
                body: data,
                validStatusCode: [.noContent, .notModified],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - save \(path)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).map { res in
                res.status == .noContent
            }
        }
        
        public func delete(
            of path: String,
            parameter: DeleteQueryParameter = .init()
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
                method: .DELETE,
                validStatusCode: [.noContent],
                errorStatusCode: [
                    .notFound: ("路径未找到 - delete \(path)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).map { _ in }
        }
        
        public func patch(
            to path: String,
            data: [PatchOperation]
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/data" + path,
                method: .PATCH,
                extraHeaders: [
                    "Content-Type": "application/json-patch+json"
                ],
                body: data,
                validStatusCode: [.noContent],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - patch \(path)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).map { _ in }
        }
        
        public func list<G: Decodable & Sendable>(
            as type: G.Type = G.self,
            parameter: GetQueryParameter = .init()
        ) -> EventLoopRes<Answer<G>, Errcase> {
            get(from: "", as: G.self, parameter: parameter).map { res in
                guard let r = res else {
                    fatalError("All 不应当为空")
                }
                
                return r
            }
        }
        
        public func get<G: Decodable & Sendable>(
            from path: String,
            as type: G.Type = G.self,
            parameter: GetQueryParameter = .init()
        ) -> EventLoopRes<Answer<G>?, Errcase> {
            send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
                method: .POST,
                body: [
                    "input": AnyCodable([:])
                ],
                validStatusCode: [.ok],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try? res.json().get()
            }
        }
    }
}
