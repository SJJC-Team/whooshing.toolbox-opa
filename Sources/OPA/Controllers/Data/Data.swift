import NIOCore
import NIOAdvanced
import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public extension OPA {
    /// 数据控制器
    ///
    /// 负责管理 OPA 中的数据（Base Documents），支持 CRUD 操作。
    final class DataController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
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
        
        /// 更新文档 (Patch)
        ///
        /// 使用 JSON Patch 格式进行增量更新。
        ///
        /// - Parameters:
        ///   - path: 数据路径
        ///   - data: Patch 操作列表
        /// - Returns: 无返回值
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
