import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle
import Logging
import LoggingAdvanced
@preconcurrency import AnyCodable

public extension OPA {
    /// 策略控制器
    ///
    /// 负责管理 OPA 中的策略模块（Policy Modules），支持增删改查。
    final class PolicyController: Controller {
        public let argument: OPA.ConnectionArgument
        public let logger: Logger
        
        init(argument: OPA.ConnectionArgument, logger: Logger) {
            self.argument = argument
            self.logger = logger
        }
        
        /// 创建或更新策略
        ///
        /// - Parameters:
        ///   - id: 策略 ID（通常为文件名，如 "authz.rego"）
        ///   - content: 策略内容（Rego 代码字符串）
        ///   - parameter: 保存参数
        /// - Returns: 无返回值
        public func save(
            by id: String,
            content: String,
            parameter: SaveQueryParameter = .init()
        ) -> EventLoopRes<Answer<NULL>, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Policy Save 操作", metadata: ["id": .string(id)])
            logger.debug("操作参数", metadata: ["content": .string(content), "parameter": .data(parameter)])
            
            return send(
                uri: "/v1/policies/\(id)",
                queries: parameter.queryItems,
                method: .PUT,
                body: content,
                logger: logger,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let ans = try? res.json(as: Answer<AnyCodable?>.self).get()
                
                ans?.logHintsIfHas(label: "Save 操作", logger: logger)
                logger.debug("Save 操作结果", metadata: ["result": .data(ans)])
                logger.info("Policy Save 操作执行完成")
                
                return ans == nil ? .init(result: .init()) : ans!.set(result: NULL())
            }.logIfFail(logger: logger)
        }
        
        /// 删除策略
        ///
        /// - Parameters:
        ///   - id: 策略 ID
        ///   - parameter: 删除参数
        /// - Returns: 无返回值
        public func delete(
            of id: String,
            parameter: DeleteQueryParameter = .init()
        ) -> EventLoopRes<Answer<NULL>, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Policy Delete 操作", metadata: ["id": .string(id)])
            logger.debug("操作参数", metadata: ["parameter": .data(parameter)])
            
            return send(
                uri: "/v1/policies/\(id)",
                queries: parameter.queryItems,
                method: .DELETE,
                logger: logger,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - delete \(id)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing {res throws(Errcase.ErrType) in
                let ans = try? res.json(as: Answer<AnyCodable?>.self).get()
                
                ans?.logHintsIfHas(label: "Delete 操作", logger: logger)
                logger.debug("Delete 操作结果", metadata: ["result": .data(ans)])
                logger.info("Policy Delete 操作执行完成")
                
                return ans == nil ? .init(result: .init()) : ans!.set(result: NULL())
            }.logIfFail(logger: logger)
        }
        
        /// 策略模块结果
        public struct PolicyResult<T: Decodable & Sendable>: Decodable, Sendable {
            /// 策略 ID
            let id: String
            /// 原始 Rego 代码
            let raw: String
            /// 解析后的 AST (如果请求了 AST)
            let ast: T
        }
        
        /// 策略 API 响应
        public typealias PolicyAnswer<T: Decodable & Sendable> = Answer<PolicyResult<T>?>
        
        /// 获取指定策略
        ///
        /// - Parameters:
        ///   - id: 策略 ID
        ///   - type: AST 映射类型
        ///   - parameter: 查询参数
        /// - Returns: 包含策略信息的 Answer，若未找到，则 ans.result == nil
        public func get<T: Decodable & Sendable>(
            at id: String,
            as type: T.Type = [String: AnyCodable].self,
            parameter: GetQueryParameter = .init()
        ) -> EventLoopRes<PolicyAnswer<T>, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Policy Get 查询", metadata: ["id": .string(id)])
            logger.debug("操作参数", metadata: ["parameter": .data(parameter)])
            
            return send(
                uri: "/v1/policies/\(id)",
                queries: parameter.queryItems,
                method: .GET,
                logger: logger,
                validStatusCode: [.ok, .notFound],
                errorStatusCode: [
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                if res.status == .notFound {
                    return .init(result: nil)
                }
                
                let wrapped = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: PolicyAnswer<T>.self)) 失败", category: .internal) {
                    try res.json(as: PolicyAnswer<T>.self).get()
                }
                return wrapped
            }.flatMapThrowing { (res: PolicyAnswer<T>) in
                res.logHintsIfHas(label: "Get 查询", logger: logger)
                logger.debug("查询结果", metadata: ["result": .data(res)])
                logger.info("Policy Get 查询执行完成")
                
                return res
            }.logIfFail(logger: logger)
        }
        
        /// 列出所有策略
        ///
        /// - Parameter type: AST 映射类型
        /// - Returns: 包含所有策略列表的 Answer
        public func list<T: Decodable & Sendable>(
            as type: T.Type = [String: AnyCodable].self
        ) -> EventLoopRes<Answer<[PolicyResult<T>]>, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Policy List 查询")
            
            return send(
                uri: "/v1/policies",
                method: .GET,
                logger: logger,
                errorStatusCode: [
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let wrapped = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<[PolicyResult<T>]>.self)) 失败", category: .internal) {
                    try res.json(as: Answer<[PolicyResult<T>]>.self).get()
                }
                return wrapped
            }.flatMapThrowing { (res: Answer<[PolicyResult<T>]>) in
                res.logHintsIfHas(label: "List 查询", logger: logger)
                logger.debug("查询结果", metadata: ["result": "\(res)"])
                logger.info("Policy List 查询执行完成")
                
                return res
            }.logIfFail(logger: logger)
        }
        
        /// 策略语法检查
        ///
        /// - Parameter policy: 要检查的策略
        /// - Returns:
        /// 若无致命错误，返回 Answer，其中可能有 warnings 以及 hints
        /// 若有致命错误，返回 Err，其中有错误的详细描述
        public func check(
            policy: String
        ) -> EventLoopRes<Result<Answer<NULL>, Err>, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行策略语法检查", metadata: ["policy": .string(policy)])
            
            return send(
                uri: "/v1/query",
                method: .POST,
                body: [
                    "query": AnyCodable(policy)
                ],
                logger: logger,
                validStatusCode: [.ok, .badRequest],
                errorStatusCode: [
                    .internalServerError: ("服务器未知错误", .internal),
                    .notImplemented: ("流式传输未实现", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                if res.status == .ok {
                    let r = try required(throws: Errcase.responseParseFailed, metadata: ["target": "\(Answer<AnyCodable?>.self)"], category: .internal) {
                        try res.json(as: Answer<AnyCodable?>.self).get()
                    }.asNull()
                    
                    r.logHintsIfHas(label: "策略语法检查", logger: logger)
                    logger.debug("策略检查通过", metadata: ["result": .data(r)])
                    logger.info("策略语法检查执行完成")
                    
                    return .success(r)
                } else {
                    let e = try required(throws: Errcase.responseParseFailed, metadata: ["target": "\(Err.self)"], category: .internal) {
                        try res.json(as: Err.self).get()
                    }
                    
                    logger.debug("策略检查未通过", metadata: ["error": .data(e)])
                    logger.info("策略语法检查执行完成")
                    
                    return .failure(e)
                }
            }.logIfFail(logger: logger)
        }
    }
}

extension OPA.PolicyController.PolicyResult: Loggerable, CustomStringConvertible {
    public var description: String {
        let indent = "    "
        let formattedRaw = raw.components(separatedBy: .newlines)
                              .map { indent + $0 }
                              .joined(separator: "\n")
        
        var output = """
        -------------------------------------------
        Policy [\(id)]:
        
        RAW:
        \(formattedRaw)
        """
        
        if let a = ast as? [String: AnyCodable] {
            let formattedAST = formatAST(a)
            output += "\n\nAST: \(formattedAST)"
        }
        
        output += "\n-------------------------------------------"

        return output
    }
    
    func formatAST(_ ast: [String: AnyCodable]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(ast)
            return String(data: data, encoding: .utf8) ?? "\(ast)"
        } catch {
            return "\(ast)"
        }
    }
}
