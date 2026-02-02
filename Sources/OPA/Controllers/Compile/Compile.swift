import NIOCore
import NIOAdvanced
import ErrorHandle
import Foundation
@preconcurrency import AnyCodable

public extension OPA {
    /// 编译控制器
    ///
    /// 负责与 OPA 的 Compile API 进行交互，支持部分求值（Partial Evaluation）和数据过滤（Data Filtering）。
    final class CompileController: Controller {
        public let argument: OPA.ConnectionArgument
        
        init(argument: OPA.ConnectionArgument) {
            self.argument = argument
        }
        
        /// 执行部分求值 (Partial Evaluation)
        ///
        /// 该方法允许你预先对查询进行部分计算。你可以提供部分已知的输入（`input`），并指定哪些部分是未知的（`unknowns`）。
        /// OPA 将尽可能多地计算查询，并返回剩余的逻辑条件。
        ///
        /// - Parameters:
        ///   - query: Rego 查询语句 (例如: "data.authz.allow == true")
        ///   - input: 输入数据对象，可以是任意 `Encodable` 类型
        ///   - options: 编译选项 `PartialOption`
        ///   - unknowns: 未知变量列表，例如 `["input.user"]`
        ///   - as: 结果解析类型，默认为 `PartialResult.self`
        ///   - parameter: 查询参数
        /// - Returns: `EventLoopRes<Answer<T>, Errcase>` 包含编译结果的 Future 对象
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
        
        /// 执行基于 UCAST 目标的数据过滤
        ///
        /// 将 Rego 策略编译为 UCAST (Universal Abstract Syntax Tree) 格式，主要用于将策略转换为数据库查询条件 (如 Mongo, ElasticSearch 等的中间表示)。
        ///
        /// - Parameters:
        ///   - path: 针对的数据/策略路径 (例如: "/authz/allow")
        ///   - input: 输入数据
        ///   - target: UCAST 目标类型 (例如 `.minimal`)
        ///   - options: UCAST 过滤选项
        ///   - unknowns: 未知变量列表
        ///   - parameter: 查询参数
        /// - Returns: 包含 `UCASTTargetResult` 的结果
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
        
        /// 执行基于 SQL 目标的数据过滤
        ///
        /// 将 Rego 策略编译为 SQL 语句的 WHERE 子句条件。这允许你在数据库层面直接应用 OPA 策略过滤数据。
        ///
        /// - Parameters:
        ///   - path: 针对的数据/策略路径
        ///   - input: 输入数据
        ///   - target: SQL 方言类型 (例如 `.mysql`, `.postgresql`)
        ///   - options: SQL 过滤选项 (可配置表名映射等)
        ///   - unknowns: 未知变量列表
        ///   - parameter: 查询参数
        ///   - as: 结果类型，默认为 `SQLTargetResult.self`
        /// - Returns: 包含 SQL 查询片段的结果
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
        
        /// 执行多目标数据过滤
        ///
        /// 同时将策略编译为多种目标格式（如同时返回 SQL 和 UCAST）。
        ///
        /// - Parameters:
        ///   - path: 针对的数据/策略路径
        ///   - input: 输入数据
        ///   - options: 多目标过滤选项 (可指定多个方言)
        ///   - unknowns: 未知变量列表
        ///   - parameter: 查询参数
        ///   - as: 结果类型，默认为 `MultiTargetResult.self`
        /// - Returns: 包含多目标结果的 `MultiTargetResult`
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
