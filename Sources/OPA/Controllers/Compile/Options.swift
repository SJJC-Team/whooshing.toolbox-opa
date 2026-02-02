public extension OPA.CompileController {
    struct PartialOption: Codable, Sendable {
        public let disableInlining: [String]?
        public let nondeterminsticBuiltins: Bool
        
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
