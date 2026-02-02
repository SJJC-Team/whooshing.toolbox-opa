import Foundation
@preconcurrency import AnyCodable

public extension OPA.CompileController {
    struct PartialResultBlock: Codable, Sendable, CustomStringConvertible {
        public let queries: [[QueryBlock]]?
        
        public var description: String {
            guard let queries = queries, !queries.isEmpty else { return "always false" }
            
            return queries.map { queryArray in
                if queryArray.isEmpty { return "always true" }
                return queryArray.map { $0.description }.joined(separator: " AND ")
            }.joined(separator: " | OR | ")
        }
    }
    
    struct QueryBlock: Codable, Sendable, CustomStringConvertible {
        public let index: Int
        public let terms: [Term]
        
        public var description: String {
            if terms.isEmpty { return "" }
            return "[" + terms.map { $0.description }.joined(separator: " ") + "]"
        }
    }
    
    struct Term: Codable, Sendable, CustomStringConvertible {
        public let type: TermType
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

    enum TermType: Sendable, Codable, CustomStringConvertible {
        case ref, `var`, number, string, bool, array, object
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

    enum TermValue: Sendable, CustomStringConvertible {
        case value(AnyCodable)
        indirect case ref([Term])
        indirect case array([Term])
        case null
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
