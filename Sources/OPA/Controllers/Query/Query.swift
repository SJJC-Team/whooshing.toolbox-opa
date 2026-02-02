import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public extension OPA {
    /// 查询控制器
    ///
    /// 提供多种查询 OPA 决策的方式，包括简单查询、针对特定数据路径的查询以及 Ad-hoc 查询。
    final class QueryController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }

        /// 简单查询
        ///
        /// 向 OPA 根路径 `/` 发送请求，通常用于查询 `default` 决策。
        ///
        /// - Parameters:
        ///   - input: 输入数据
        ///   - as: 结果类型
        ///   - parameter: 查询参数
        /// - Returns: 查询结果
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
        
        /// 数据路径查询
        ///
        /// 查询 OPA 中指定路径的数据或策略决策（例如 `/v1/data/authz/allow`）。
        ///
        /// - Parameters:
        ///   - path: 数据路径
        ///   - input: 输入数据
        ///   - as: 结果类型
        ///   - parameter: 查询参数
        /// - Returns: 包含结果的 Answer
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
        
        /// Ad-hoc 查询
        ///
        /// 执行任意的 Rego 查询语句（例如 `data.authz.allow == true`）。
        ///
        /// - Parameters:
        ///   - query: Rego 查询语句
        ///   - input: 输入数据
        ///   - as: 结果类型
        ///   - parameter: 查询参数
        /// - Returns: 包含结果的 Answer
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
