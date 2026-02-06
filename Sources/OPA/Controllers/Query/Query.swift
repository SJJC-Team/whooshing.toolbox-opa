import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle
import Logging
import LoggingAdvanced
@preconcurrency import AnyCodable

public extension OPA {
    /// 查询控制器
    ///
    /// 提供多种查询 OPA 决策的方式，包括简单查询、针对特定数据路径的查询以及 Ad-hoc 查询。
    final class QueryController: Controller {
        public let argument: OPA.ConnectionArgument
        public let logger: Logger
        
        init(argument: OPA.ConnectionArgument, logger: Logger) {
            self.argument = argument
            self.logger = logger
        }

        /// 简单查询
        ///
        /// 向 OPA 根路径 `/` 发送请求，通常用于查询 `default` 决策。
        ///
        /// - Parameters:
        ///   - input: 输入数据
        ///   - type: 结果类型
        ///   - parameter: 查询参数
        /// - Returns: 查询结果
        public func simple<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            input: G,
            as type: T.Type = T.self,
            parameter: SimpleQueryParameter = .init()
        ) -> EventLoopRes<T, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Simple 查询")
            logger.debug("查询参数", metadata: ["input": "\(input)", "parameter": .data(parameter)])
            
            return send(
                uri: "/",
                queries: parameter.queryItems,
                method: .POST,
                body: input,
                logger: logger,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - simple \(input)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try required(throws: Errcase.responseParseFailed, metadata: ["target": "\(T.self)"], category: .internal) {
                    try res.json().get()
                }
            }.flatMapThrowing { (res: T) in
                logger.debug("查询结果", metadata: ["result": "\(res)"])
                logger.info("Simple 查询执行完成")
                return res
            }.logIfFail(logger: logger)
        }
        
        /// 数据路径查询
        ///
        /// 查询 OPA 中指定路径的数据或策略决策（例如 `/v1/data/authz/allow`）。
        ///
        /// - Parameters:
        ///   - path: 数据路径
        ///   - input: 输入数据
        ///   - type: 结果类型
        ///   - parameter: 查询参数
        /// - Returns: 包含结果的 Answer
        ///     若路径 path 未找到(一般认为 false)，则该函数返回值 ans.result == nil
        ///     若查询成功且结果为 undefined(一般认为 false)，则该函数返回值 ans.result == nil
        ///     若查询成功且结果不为 undefined，则该函数返回值 ans.result 为预期值
        public func data<T: Encodable & Sendable, G: Decodable & Sendable>(
            from path: String,
            input: T,
            as type: G.Type = G.self,
            parameter: DataQueryParameter = .init()
        ) -> EventLoopRes<Answer<G?>, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Data 查询", metadata: ["path": .string(path)])
            logger.debug("查询参数", metadata: ["input": "\(input)", "parameter": .data(parameter)])
            
            return send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
                method: .POST,
                body: [
                    "input" : AnyCodable(input)
                ],
                logger: logger,
                validStatusCode: [.ok],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let ans = try? res.json(as: Answer<G?>.self).get()
                
                ans?.logHintsIfHas(label: "Data 查询", logger: logger)
                logger.debug("查询结果", metadata: ["result": .data(ans)])
                logger.info("Data 查询执行完成")
                
                return ans ?? .init(result: nil)
            }.logIfFail(logger: logger)
        }
        
        /// Ad-hoc 查询
        ///
        /// 允许客户端发送任意的 Rego 查询语句并在 OPA 上执行，而无需在服务器上预先保存策略。
        /// 适用于动态生成查询或调试目的。
        ///
        /// - Parameters:
        ///   - query: Rego 查询语句 (例如: `data.authz.allow == true`)
        ///   - input: 输入数据对象 (作为 `input` 全局变量在查询中使用)
        ///   - type: 预期结果的数据类型
        ///   - parameter: 查询配置参数
        /// - Returns: `EventLoopRes<Answer<T?>, Errcase>` 包含查询结果的 Future 对象
        public func adhoc<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            query: String,
            input: G,
            as type: T.Type = T.self,
            parameter: AdhocQueryParameter = .init()
        ) -> EventLoopRes<Answer<T?>, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Adhoc 查询", metadata: ["query": .string(query)])
            logger.debug("查询参数", metadata: ["input": "\(input)", "parameter": .data(parameter)])
            
            return send(
                uri: "/v1/query",
                queries: parameter.queryItems,
                method: .POST,
                body: [
                    "query": AnyCodable(query),
                    "input": AnyCodable(input)
                ],
                logger: logger,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal),
                    .notImplemented: ("流式传输未实现", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                try required(throws: Errcase.responseParseFailed, metadata: ["target": "\(Answer<T?>.self)"], category: .internal) {
                    try res.json().get()
                }
            }.flatMapThrowing { (res: Answer<T?>) in
                res.logHintsIfHas(label: "Adhoc 查询", logger: logger)
                logger.debug("查询结果", metadata: ["result": "\(res)"])
                logger.info("Adhoc 查询执行完成")
                
                return res
            }.logIfFail(logger: logger)
        }
    }
}
