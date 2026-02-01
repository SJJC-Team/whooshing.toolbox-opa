import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle
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
            input: G,
            as: T.Type = T.self
        ) -> EventLoopRes<T, Errcase> {
            send(
                uri: "/",
                method: .POST,
                body: input,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - simple \(input)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: T.self)) 失败", category: .internal) {
                    try res.json().get()
                }
            }
        }
        
        public func data<T: Encodable & Sendable, G: Decodable & Sendable>(
            from path: String,
            input: T,
            as type: G.Type = G.self,
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
                validStatusCode: [.ok, .notFound],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                if res.status == .notFound {
                    return nil
                }
                
                let wrapped: SingleResult<G> = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: SingleResult<G>.self)) 失败", category: .internal) {
                    try res.json().get()
                }
                return wrapped.result
            }
        }
        
        public func adhoc<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            query: String,
            input: G,
            as type: T.Type = T.self,
        ) -> EventLoopRes<T, Errcase> {
            send(
                uri: "/v1/query",
                method: .POST,
                body: [
                    "query": AnyCodable(query),
                    "input": AnyCodable(input)
                ],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal),
                    .notImplemented: ("流式传输未实现", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let wrapped: SingleResult<T> = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: SingleResult<T>.self)) 失败", category: .internal) {
                    try res.json().get()
                }
                guard let result = wrapped.result else {
                    let result = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: T.self)) 失败", category: .internal) {
                        try res.json(as: T.self).get()
                    }
                    return result
                }
                return result
            }
        }
    }
}
