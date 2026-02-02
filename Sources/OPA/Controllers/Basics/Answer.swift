import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public extension OPA {
    struct Answer<T: Decodable & Sendable>: Decodable, Sendable {
        public let result: T
        public let warnings: [Warning]?
        public let decisionId: String?
        public let metrics: [MetricKey: Int64]?
        public let explanation: [AnyCodable]?

        enum CodingKeys: String, CodingKey {
            case result
            case warnings
            case decisionId = "decision_id"
            case metrics
            case explanation
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let value = try? container.decode(T.self, forKey: .result) {
                self.result = value
            } else if let nilValue = Optional<Any>.none as? T {
                self.result = nilValue
            } else {
                self.result = try container.decode(T.self, forKey: .result)
            }

            self.warnings = try container.decodeIfPresent([Warning].self, forKey: .warnings)
            self.decisionId = try container.decodeIfPresent(String.self, forKey: .decisionId)
            self.metrics = try container.decodeIfPresent([MetricKey: Int64].self, forKey: .metrics)
            self.explanation = try container.decodeIfPresent([AnyCodable].self, forKey: .explanation)
        }
    }
    
    enum MetricKey: String, Codable, Sendable {
        case timerRegoInputParse                = "timer_rego_input_parse_ns"
        case timerRegoQueryParse                = "timer_rego_query_parse_ns"
        case timerRegoQueryCompile              = "timer_rego_query_compile_ns"
        case timerRegoQueryEval                 = "timer_rego_query_eval_ns"
        case timerRegoModuleParse               = "timer_rego_module_parse_ns"
        case timerRegoModuleCompile             = "timer_rego_module_compile_ns"
        case timerServerHandler                 = "timer_server_handler_ns"
        case counterServerQueryCacheHit         = "counter_server_query_cache_hit"
    }
}

public extension OPA {
    struct ResultBlock: Codable, Sendable {
        public let queries: [[QueryBlock]]?
    }
    
    struct QueryBlock: Codable, Sendable {
        public let index: Int
        public let terms: [Term]
    }
    
    enum TermType: Sendable, Codable, CustomStringConvertible {
        case ref
        case variable
        case number
        case string
        case bool
        case array
        case object
        case unknown(String)
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self = .init(rawValue: try container.decode(String.self))
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }
        
        public var description: String {
            switch self {
            case .ref: "ref"
            case .variable: "variable"
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
            case "variable": .variable
            case "number": .number
            case "string": .string
            case "bool": .bool
            case "array": .array
            case "object": .object
            default: .unknown(rawValue)
            }
        }
    }
    
    struct Term: Codable, Sendable {
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
            case .variable, .number, .string, .bool, .object:
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
    }

    enum TermValue: Sendable {
        case value(AnyCodable)
        indirect case ref([Term])
        indirect case array([Term])
        case null
        case unknown
    }
}
