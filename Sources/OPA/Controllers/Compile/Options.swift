public extension OPA.CompileController {
    /// 部分求值选项
    struct PartialOption: Codable, Sendable {
        /// 禁止内联的规则或函数路径列表
        public let disableInlining: [String]?
        /// 是否将不确定的内建函数（如 `time.now_ns`）视为动态值而非在该时刻求值
        public let nondeterminsticBuiltins: Bool
        
        public init(disableInlining: [String]? = nil, nondeterminsticBuiltins: Bool = false) {
            self.disableInlining = disableInlining
            self.nondeterminsticBuiltins = nondeterminsticBuiltins
        }
    }
    
    /// 多目标数据过滤选项
    struct MultiTargetDataFilterOption: Codable, Sendable {
        /// 需要生成的目标方言列表
        public let targetDialects: [TargetDialect]
        /// 禁止内联的路径
        public let disableInlining: [String]
        /// 用于覆盖默认规则的 Mask 规则路径
        public let maskRule: String?
        /// 针对 SQL 目标的表名映射配置
        /// 键为 SQL 方言，值为 [原始表名: [配置项: 实际值]] 的嵌套字典
        public let targetSQLTableMappings: [TargetDialect.SQL: [String: [String: String]]]
        
        public init(
            targetDialects: [TargetDialect] = TargetDialect.allCases,
            disableInlining: [String] = [],
            maskRule: String? = nil,
            targetSQLTableMappings: [TargetDialect.SQL: [String: [String: String]]] = [:]
        ) {
            self.disableInlining = disableInlining
            self.maskRule = maskRule
            self.targetDialects = targetDialects
            self.targetSQLTableMappings = targetSQLTableMappings
        }
        
        enum CodingKeys: CodingKey {
            case targetDialects
            case disableInlining
            case maskRule
            case targetSQLTableMappings
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let rawSubValues = try container.decode([String].self, forKey: .targetDialects)
            
            self.targetDialects = rawSubValues.compactMap { raw in
                TargetDialect.allCases.first { $0.subValue == raw }
            }
            
            self.disableInlining = try container.decode([String].self, forKey: .disableInlining)
            self.maskRule = try container.decodeIfPresent(String.self, forKey: .maskRule)
            
            let maps = try container.decode([String : [String : [String : String]]].self, forKey: .targetSQLTableMappings).map {
                (TargetDialect.SQL(rawValue: $0.key)!, $0.value)
            }
            
            self.targetSQLTableMappings = .init(uniqueKeysWithValues: maps)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(targetDialects.map { $0.subValue }, forKey: .targetDialects)
            try container.encode(disableInlining, forKey: .disableInlining)
            try container.encodeIfPresent(maskRule, forKey: .maskRule)
            
            let raw = [String : [String : [String : String]]](uniqueKeysWithValues: self.targetSQLTableMappings.map {
                ($0.key.rawValue, $0.value)
            })
            
            try container.encode(raw, forKey: .targetSQLTableMappings)
        }
    }
    
    /// UCAST 目标数据过滤选项
    struct UCASTTargetDataFilterOption: Codable, Sendable {
        /// 禁止内联的路径
        public let disableInlining: [String]
        /// Mask 规则路径
        public let maskRule: String?
        
        public init(
            disableInlining: [String] = [],
            maskRule: String? = nil
        ) {
            self.disableInlining = disableInlining
            self.maskRule = maskRule
        }
    }
    
    /// SQL 目标数据过滤选项
    struct SQLTargetDataFilterOption: Encodable, Sendable {
        /// 指定 SQL 方言 (内部设置)
        public internal(set) var sqlDialect: TargetDialect.SQL!
        /// 禁止内联的路径
        public let disableInlining: [String]
        /// Mask 规则路径
        public let maskRule: String?
        /// 表名/列名映射配置
        public let tableMapping: [String: [String: String]]
        
        public init(
            disableInlining: [String] = [],
            maskRule: String? = nil,
            targetSQLTableMapping: [String: [String: String]] = [:]
        ) {
            self.disableInlining = disableInlining
            self.maskRule = maskRule
            self.tableMapping = targetSQLTableMapping
        }
        
        enum CodingKeys: CodingKey {
            case disableInlining
            case maskRule
            case targetSQLTableMappings
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.disableInlining, forKey: .disableInlining)
            try container.encodeIfPresent(self.maskRule, forKey: .maskRule)
            try container.encode([sqlDialect.rawValue: self.tableMapping], forKey: .targetSQLTableMappings)
        }
        
        func set(sqlDialect: TargetDialect.SQL) -> Self {
            var res = Self(
                disableInlining: disableInlining,
                maskRule: maskRule,
                targetSQLTableMapping: tableMapping
            )
            
            res.sqlDialect = sqlDialect
            return res
        }
    }
   
    /// 编译目标方言
    enum TargetDialect: CaseIterable, Hashable, Sendable {
        /// UCAST (Universal Abstract Syntax Tree) 格式
        case ucast(UCAST)
        /// SQL 语句格式
        case sql(SQL)
        
        public enum UCAST: String, CaseIterable, Sendable {
            case all = "all"
            case minimal = "minimal"
            case linq = "linq"
            case prisma = "prisma"
            
            var value: String {
                "application/vnd.opa.ucast.\(self.rawValue)+json"
            }
            
            var subValue: String {
                "ucast+\(self.rawValue)"
            }
        }
        
        public enum SQL: String, Hashable, Codable, CaseIterable, Sendable {
            case sqlserver = "sqlserver"
            case mysql = "mysql"
            case postgresql = "postgresql"
            case sqlite = "sqlite"
            
            var value: String {
                "application/vnd.opa.sql.\(self.rawValue)+json"
            }
            
            var subValue: String {
                "sql+\(self.rawValue)"
            }
        }
        
        var subValue: String {
            switch self {
            case .ucast(let ucast):
                return ucast.subValue
            case .sql(let sql):
                return sql.subValue
            }
        }
        
        public static let allCases: [OPA.CompileController.TargetDialect] = [
            .ucast(.all),
            .ucast(.minimal),
            .ucast(.linq),
            .ucast(.prisma),
            .sql(.sqlserver),
            .sql(.mysql),
            .sql(.postgresql),
            .sql(.sqlite)
        ]
    }
}
