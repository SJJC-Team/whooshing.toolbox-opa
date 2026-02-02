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
            as: T.Type = PartialResult.self,
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
        
        public func uCastDataFilter<G: Encodable & Sendable>(
            path: String,
            input: G,
            target: TargetDialect.UCAST,
            options: UCASTTargetDataFilterOption = .init(),
            unknowns: [String],
            parameter: QueryParameter = .init()
        ) -> EventLoopRes<Answer<UCASTTargetResult>, Errcase> {
            __dataFilter(
                path: path,
                input: input,
                accept: target.value,
                options: options,
                unknowns: unknowns
            )
        }
        
        public func sqlDataFilter<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            path: String,
            input: G,
            target: TargetDialect.SQL,
            options: SQLTargetDataFilterOption = .init(),
            unknowns: [String],
            parameter: QueryParameter = .init(),
            as: T.Type = SQLTargetResult.self
        ) -> EventLoopRes<Answer<T>, Errcase> {
            __dataFilter(
                path: path,
                input: input,
                accept: target.value,
                options: options.set(sqlDialect: target),
                unknowns: unknowns
            )
        }
        
        public func dataFilter<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            path: String,
            input: G,
            options: MultiTargetDataFilterOption = .init(),
            unknowns: [String],
            parameter: QueryParameter = .init(),
            as: T.Type = MultiTargetResult.self
        ) -> EventLoopRes<Answer<T>, Errcase> {
            __dataFilter(
                path: path,
                input: input,
                accept: "application/vnd.opa.multitarget+json",
                options: options,
                unknowns: unknowns
            )
        }
        
        func __dataFilter<
            G: Encodable & Sendable,
            T: Decodable & Sendable,
            F: Encodable & Sendable
        >(
            path: String,
            input: G,
            accept: String,
            options: F,
            unknowns: [String],
            parameter: QueryParameter = .init()
        ) -> EventLoopRes<Answer<T>, Errcase> {
            send(
                uri: "/v1/compile" + path,
                queries: parameter.queryItems,
                method: .POST,
                extraHeaders: [
                    "Accept": accept
                ],
                body: [
                    "input": AnyCodable(input),
                    "options": AnyCodable(options),
                    "unknowns": AnyCodable(unknowns)
                ],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - data_filter \(path)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<T>.self)) 失败", category: .internal) {
                    try res.json(accept: accept).get()
                }
            }
        }
    }
}
