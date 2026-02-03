import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle
import Logging
@preconcurrency import AnyCodable

public extension OPA {
    /// 数据控制器
    ///
    /// 负责管理 OPA 中的数据（Base Documents），支持 CRUD 操作。
    final class DataController: Controller {
        public let argument: OPA.ConnectionArgument
        public let logger: Logger
        
        init(argument: OPA.ConnectionArgument, logger: Logger) {
            self.argument = argument
            self.logger = logger
        }
        
        /// 创建或覆盖文档
        ///
        /// - Parameters:
        ///   - path: 数据路径（例如 "/users/alice"）
        ///   - ifNoneMatch: 用于并发控制，设为 "*" 表示仅当路径不存在时创建
        ///   - data: 要保存的数据内容
        ///   - parameter: 保存参数（可包含 metrics）
        /// - Returns: `True` 表示创建成功，`False` 表示未修改（即内容未变或 ifNoneMatch 检查失败）
        public func save<T: Encodable & Sendable>(
            on path: String,
            ifNoneMatch: String? = "*",
            data: T,
            parameter: SaveQueryParameter = .init()
        ) -> EventLoopRes<Bool, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Data Save 操作", metadata: ["path": .string(path)])
            logger.debug("操作参数", metadata: ["parameter": .data(parameter)])
            
            return send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
                method: .PUT,
                extraHeaders: ifNoneMatch == nil ? [:] : [
                    "If-None-Match": ifNoneMatch!
                ],
                body: data,
                logger: logger,
                validStatusCode: [.noContent, .notModified],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - save \(path)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res in
                let r = res.status == .noContent
                logger.info("Data Save 操作执行完成", metadata: ["result": .stringConvertible(r)])
                return r
            }.logIfFail(logger: logger)
        }
        
        /// 删除文档
        ///
        /// - Parameters:
        ///   - path: 数据路径
        ///   - parameter: 删除参数
        /// - Returns: 无返回值，成功或抛出错误
        public func delete(
            of path: String,
            parameter: DeleteQueryParameter = .init()
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Data Delete 操作", metadata: ["path": .string(path)])
            logger.debug("操作参数", metadata: ["parameter": .data(parameter)])
            
            return send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
                method: .DELETE,
                logger: logger,
                validStatusCode: [.noContent],
                errorStatusCode: [
                    .notFound: ("路径未找到 - delete \(path)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { _ in
                logger.info("Data Delete 操作执行完成")
            }.logIfFail(logger: logger)
        }
        
        /// 更新文档 (Patch)
        ///
        /// 使用 JSON Patch 格式进行增量更新。
        ///
        /// - Parameters:
        ///   - path: 数据路径
        ///   - operations: Patch 操作列表
        /// - Returns: 无返回值
        public func patch(
            to path: String,
            operations: [PatchOperation]
        ) -> EventLoopRes<Void, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Data Patch 操作", metadata: ["path": .string(path)])
            logger.debug("操作参数", metadata: ["operations": .data(operations)])
            
            return send(
                uri: "/v1/data" + path,
                method: .PATCH,
                extraHeaders: [
                    "Content-Type": "application/json-patch+json"
                ],
                body: operations,
                logger: logger,
                validStatusCode: [.noContent],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .notFound: ("路径未找到 - patch \(path)", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { _ in
                logger.info("Data Patch 操作执行完成")
            }.logIfFail(logger: logger)
        }
        
        /// 获取所有数据
        ///
        /// - Parameters:
        ///   - type: 结果映射类型
        ///   - parameter: 查询参数
        /// - Returns: 包含数据的 Answer
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
        
        /// 获取指定路径的数据
        ///
        /// - Parameters:
        ///   - path: 数据路径
        ///   - type: 结果映射类型
        ///   - parameter: 查询参数
        /// - Returns: 包含数据的 Answer，如果不存在则为 nil
        public func get<G: Decodable & Sendable>(
            from path: String,
            as type: G.Type = G.self,
            parameter: GetQueryParameter = .init()
        ) -> EventLoopRes<Answer<G>?, Errcase> {
            let logger = getRequestLogger()
            
            logger.info("执行 Data Get 查询", metadata: ["path": .string(path)])
            logger.debug("操作参数", metadata: ["parameter": .data(parameter)])
            
            return send(
                uri: "/v1/data" + path,
                queries: parameter.queryItems,
                method: .POST,
                body: [
                    "input": AnyCodable([:])
                ],
                logger: logger,
                validStatusCode: [.ok],
                errorStatusCode: [
                    .badRequest: ("请求不合法", .external),
                    .internalServerError: ("服务器未知错误", .internal)
                ]
            ).flatMapThrowing { res throws(Errcase.ErrType) in
                let r = try? res.json(as: Answer<G>.self).get()
                logger.debug("取得查询结果", metadata: ["result":r == nil ? "nil" : "\(r!)"])
                logger.info("Data Get 查询执行完成")
                return r
            }
        }
    }
}
