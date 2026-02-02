import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public extension OPA {
    struct Answer<T: Decodable & Sendable>: Decodable, Sendable, CustomStringConvertible {
        public let result: T
        public let warnings: [Warning]?
        public let decisionId: String?
        public let metrics: [MetricKey: Int64]?
        public let explanation: [AnyCodable]?

        enum CodingKeys: String, CodingKey {
            case result, warnings, metrics, explanation
            case decisionId = "decision_id"
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

        public var description: String {
            let resDesc = (result as? CustomStringConvertible)?.description ?? "\(result)"
            var info = ["res: \(resDesc)"]
            
            if let ms = metrics?[.timerRegoQueryEval] {
                info.append("time: \(Double(ms)/1_000_000.0)ms")
            }
            
            if let wCount = warnings?.count, wCount > 0 {
                info.append("warnings: \(wCount)")
            }
            
            return "Answer(\(info.joined(separator: "; ")))"
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
