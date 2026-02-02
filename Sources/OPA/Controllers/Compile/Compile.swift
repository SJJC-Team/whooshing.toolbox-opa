import NIOCore
import NIOAdvanced
import ErrorHandle
import Foundation
@preconcurrency import AnyCodable

public extension OPA {
    final class CompileController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }
        
        public func partial<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        > (
            query: String,
            input: G?,
            options: PartialOption = .init(),
            unknowns: [String],
            as: T.Type = PartialResultBlock.self,
            parameter: QueryParameter = .init()
        ) -> EventLoopRes<Answer<T>, Errcase> {
            send(
                uri: "/v1/compile",
                queries: parameter.queryItems,
                method: .POST,
                extraHeaders: [:],
                body: [
                    "query": AnyCodable(query),
                    "input": AnyCodable(input),
                    "options": AnyCodable(options),
                    "unknowns": AnyCodable(unknowns)
                ],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<T>.self)) 失败", category: .internal) {
                    try res.json().get()
                }
            }
        }
        
        public func dataFilter<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            path: String,
            input: G,
            options: DataFilterOption = .init(),
            unknowns: [String],
            as: T.Type = T.self,
            parameter: QueryParameter = .init()
        ) -> EventLoopRes<Answer<T>, Errcase> {
            send(
                uri: "/v1/compile" + path,
                queries: parameter.queryItems,
                method: .POST,
                extraHeaders: [
                    "Accept": options.format.value
                ],
                body: [
                    "input": AnyCodable(input),
                    "options": AnyCodable(options),
                    "unknowns": AnyCodable(unknowns)
                ],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<T>.self)) 失败", category: .internal) {
                    try res.json().get()
                }
            }
        }
    }
}
