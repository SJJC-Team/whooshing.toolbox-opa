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
            as: T.Type = T.self,
            parameter: QueryParameter = .init()
        ) -> EventLoopRes<Answer<T?>, Errcase> {
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
                try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<T?>.self)) 失败", category: .internal) {
                    try res.json().get()
                }
            }
        }
        
        public func getDataFilters<
            G: Encodable & Sendable,
            T: Decodable & Sendable
        >(
            path: String,
            input: G,
            options: DataFilterOption = .init(),
            unknowns: [String],
            as: T.Type = T.self,
            parameter: QueryParameter = .init()
        ) -> EventLoopRes<Answer<T?>, Errcase> {
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
                try required(throws: Errcase.responseParseFailed, "将结果解析为类型 \(String(describing: Answer<T?>.self)) 失败", category: .internal) {
                    try res.json().get()
                }
            }
        }
    }
}

public extension OPA {
    struct PartialOption: Codable, Sendable {
        let disableInlining: [String]?
        let nondeterminsticBuiltins: Bool
        
        public init(disableInlining: [String]? = nil, nondeterminsticBuiltins: Bool = false) {
            self.disableInlining = disableInlining
            self.nondeterminsticBuiltins = nondeterminsticBuiltins
        }
    }
    
    struct DataFilterOption: Codable, Sendable {
        public let disableInlining: [String]?
        public let maskRule: String?
        public let format: DataFilterFormat
        public let targetDialects: Set<String>?
        public let targetSQLTableMappings: [String: [String]]?
        
        public init(
            format: DataFilterFormat = .allTarget,
            disableInlining: [String]? = nil,
            maskRule: String? = nil,
            targetSQLTableMappings: [String : [String]]? = nil
        ) {
            self.disableInlining = disableInlining
            self.maskRule = maskRule
            self.format = format
            self.targetDialects = format.subValue
            self.targetSQLTableMappings = targetSQLTableMappings
        }
    }
    
    indirect enum DataFilterFormat: Codable, Sendable {
        case multitarget(Set<Section>)
        case specific(Section)
        
        public enum Section: Codable, Hashable, Sendable {
            case ucast(UCAST)
            case sql(SQL)
            
            public enum UCAST: String, Codable, CaseIterable, Sendable {
                case all = "all"
                case minimal = "minimal"
                case linq = "linq"
                case prisma = "prisma"
            }
            
            public enum SQL: String, Codable, CaseIterable, Sendable {
                case sqlserver = "sqlserver"
                case mysql = "mysql"
                case postgresql = "postgresql"
                case sqlite = "sqlite"
            }
            
            var value: String {
                switch self {
                case .ucast(let ucast):
                    return "application/vnd.opa.ucast." + ucast.rawValue + "+json"
                case .sql(let sql):
                    return "application/vnd.opa.sql." + sql.rawValue + "+json"
                }
            }
        }
        
        var value: String {
            switch self {
            case .multitarget:
                return "application/vnd.opa.multitarget+json"
            case .specific(let section):
                return section.value
            }
        }
        
        var subValue: Set<String>? {
            switch self {
            case .multitarget(let set):
                Set(set.map { $0.value })
            case .specific:
                nil
            }
        }
        
        public static var allTarget: DataFilterFormat {
            .multitarget(
                Set(
                    Section.UCAST.allCases.map { Section.ucast($0) } +
                    Section.SQL.allCases.map { Section.sql($0) }
                )
            )
        }
    }
}
