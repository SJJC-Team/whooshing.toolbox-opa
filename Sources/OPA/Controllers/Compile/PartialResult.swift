import Foundation
@preconcurrency import AnyCodable

public extension OPA.CompileController {
    /// 部分求值结果
    struct PartialResult: Codable, Sendable, CustomStringConvertible {
        /// 剩余查询条件列表
        ///
        /// 这是一个二维数组，表示析取范式 (DNF) 结构：
        /// 外层数组表示 OR 关系，内层数组表示 AND 关系。
        /// 例如: `[[a, b], [c]]` 表示 `(a AND b) OR c`。
        public let queries: [[QueryBlock]]?
        
        public var description: String {
            guard let queries = queries, !queries.isEmpty else { return "always false" }
            
            return queries.map { queryArray in
                if queryArray.isEmpty { return "always true" }
                return queryArray.map { $0.description }.joined(separator: " AND ")
            }.joined(separator: " | OR | ")
        }
    }
    
    /// 查询块
    struct QueryBlock: Codable, Sendable, CustomStringConvertible {
        /// 索引
        public let index: Int
        /// 表达式项列表
        public let terms: [Term]
        
        public var description: String {
            if terms.isEmpty { return "" }
            return "[" + terms.map { $0.description }.joined(separator: " ") + "]"
        }
    }
    
    /// 表达式项
    struct Term: Codable, Sendable, CustomStringConvertible {
        /// 项类型
        public let type: TermType
        /// 项值
        public let value: TermValue

        enum CodingKeys: String, CodingKey {
            case type, value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(TermType.self, forKey: .type)
            self.type = type

            switch type {
            case .ref:
                let val = try container.decode([Term].self, forKey: .value)
                self.value = .ref(val)
            case .array:
                let val = try container.decode([Term].self, forKey: .value)
                self.value = .array(val)
            case .var, .number, .string, .bool, .object:
                let val = try container.decode(AnyCodable.self, forKey: .value)
                self.value = .value(val)
            case .unknown(_):
                self.value = .unknown
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            switch value {
            case .value(let val): try container.encode(val, forKey: .value)
            case .ref(let val): try container.encode(val, forKey: .value)
            case .array(let val): try container.encode(val, forKey: .value)
            case .null: try container.encodeNil(forKey: .value)
            case .unknown: break
            }
        }
        
        public var description: String {
            return "\(type)(\(value.description))"
        }
    }

    /// 表达式项类型
    enum TermType: Sendable, Codable, CustomStringConvertible {
        /// 引用 (Ref)
        case ref
        /// 变量 (Var)
        case `var`
        /// 数字 (Number)
        case number
        /// 字符串 (String)
        case string
        /// 布尔值 (Bool)
        case bool
        /// 数组 (Array)
        case array
        /// 对象 (Object)
        case object
        /// 未知类型 (Unknown)
        case unknown(String)
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            self = .init(rawValue: raw)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }
        
        public var description: String {
            switch self {
            case .ref: "ref"
            case .var: "var"
            case .number: "number"
            case .string: "string"
            case .bool: "bool"
            case .array: "array"
            case .object: "object"
            case .unknown(let str): str
            }
        }
        
        init(rawValue: String) {
            self = switch rawValue {
            case "ref": .ref
            case "var": .var
            case "number": .number
            case "string": .string
            case "bool": .bool
            case "array": .array
            case "object": .object
            default: .unknown(rawValue)
            }
        }
    }

    /// 表达式项值
    ///
    /// 表示 Rego 表达式中具体的值。
    enum TermValue: Sendable, CustomStringConvertible {
        /// 静态值 (常量), 包含数字、字符串、布尔值等
        case value(AnyCodable)
        /// 引用值, 指向变量或数据路径
        indirect case ref([Term])
        /// 数组值, 包含一组 Term
        indirect case array([Term])
        /// 空值 (null)
        case null
        /// 未知值 (当解析失败或类型未知时使用)
        case unknown
        
        public var description: String {
            switch self {
            case .value(let codable):
                if let str = codable.value as? String {
                    return "\"\(str)\""
                }
                return "\(codable.value)"
                
            case .ref(let terms):
                return terms.map { term in
                    if case .value(let c) = term.value, let s = c.value as? String {
                        return s
                    }
                    return term.description
                }.joined(separator: ".")
                
            case .array(let terms):
                return "[" + terms.map { $0.description }.joined(separator: ", ") + "]"
                
            case .null:
                return "null"
                
            case .unknown:
                return "<unknown>"
            }
        }
    }
}
