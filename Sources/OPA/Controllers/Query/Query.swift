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
            as: T.Type = T.self,
            parameter: SimpleQueryParameter = .init()
        ) -> EventLoopRes<T, Errcase> {
            send(
                uri: "/",
                queries: parameter.queryItems,
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
            parameter: DataQueryParameter = .init()
        ) -> EventLoopRes<Answer<G>?, Errcase> {
            send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
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
                
                return try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<G>?.self)) 失败", category: .internal) {
                    try res.json().get()
                }
            }
        }
        
        public func adhoc<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            query: String,
            input: G,
            as type: T.Type = T.self,
            parameter: AdhocQueryParameter = .init()
        ) -> EventLoopRes<Answer<T?>, Errcase> {
            send(
                uri: "/v1/query",
                queries: parameter.queryItems,
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
                try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<T?>.self)) 失败", category: .internal) {
                    try res.json().get()
                }
            }
        }
    }
}
