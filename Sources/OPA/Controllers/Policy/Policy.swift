import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle

public extension OPA {
    /// 策略控制器
    ///
    /// 负责管理 OPA 中的策略模块（Policy Modules），支持增删改查。
    final class PolicyController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
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
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                queries: parameter.queryItems,
                method: .PUT,
                body: content,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).map { _ in }
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
        ) -> EventLoopRes<Void, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                queries: parameter.queryItems,
                method: .DELETE,
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - delete \(id)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).map { _ in }
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
        public typealias PolicyAnswer<T: Decodable & Sendable> = Answer<PolicyResult<T>>
        
        /// 获取指定策略
        ///
        /// - Parameters:
        ///   - id: 策略 ID
        ///   - type: AST 映射类型
        ///   - parameter: 查询参数
        /// - Returns: 包含策略信息的 Answer
        public func get<T: Decodable & Sendable>(
            at id: String,
            as type: T.Type = T.self,
            parameter: GetQueryParameter = .init()
        ) -> EventLoopRes<PolicyAnswer<T>?, Errcase> {
            send(
                uri: "/v1/policies/\(id)",
                queries: parameter.queryItems,
                method: .GET,
                validStatusCode: [.ok, .notFound],
                errorStatusCode: [
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                if res.status == .notFound {
                    return nil
                }
                
                let wrapped = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: PolicyAnswer<T>.self)) 失败", category: .internal) {
                    try res.json(as: PolicyAnswer<T>.self).get()
                }
                return wrapped
            }
        }
        
        /// 列出所有策略
        ///
        /// - Parameter type: AST 映射类型
        /// - Returns: 包含所有策略列表的 Answer
        public func list<T: Decodable & Sendable>(
            as type: T.Type = T.self
        ) -> EventLoopRes<Answer<[PolicyResult<T>]>, Errcase> {
            send(
                uri: "/v1/policies",
                method: .GET,
                errorStatusCode: [
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let wrapped = try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<[PolicyResult<T>]>.self)) 失败", category: .internal) {
                    try res.json(as: Answer<[PolicyResult<T>]>.self).get()
                }
                return wrapped
            }
        }
    }
}
