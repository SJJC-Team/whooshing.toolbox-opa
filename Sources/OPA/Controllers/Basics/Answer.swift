import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public extension OPA {
    /// OPA API 响应通用包装器
    ///
    /// 所有 OPA API 的响应通常都包含在一个 result 字段中，并附带度量信息、决策 ID 等元数据。
    struct Answer<T: Decodable & Sendable>: Decodable, Sendable, CustomStringConvertible {
        /// API 调用的主要结果
        public let result: T
        /// 警告信息列表
        public let warnings: [Warning]?
        /// 决策 ID (用于审计和追踪)
        public let decisionId: String?
        /// 性能度量指标
        public let metrics: [MetricKey: Int64]?
        /// 解释信息 (仅当请求中启用了 explain 时存在)
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
    
    /// OPA 性能度量指标键
    enum MetricKey: String, Codable, Sendable {
        /// 输入解析耗时 (ns)
        case timerRegoInputParse                = "timer_rego_input_parse_ns"
        /// 查询解析耗时 (ns)
        case timerRegoQueryParse                = "timer_rego_query_parse_ns"
        /// 查询编译耗时 (ns)
        case timerRegoQueryCompile              = "timer_rego_query_compile_ns"
        /// 查询评估耗时 (ns)
        case timerRegoQueryEval                 = "timer_rego_query_eval_ns"
        /// 模块解析耗时 (ns)
        case timerRegoModuleParse               = "timer_rego_module_parse_ns"
        /// 模块编译耗时 (ns)
        case timerRegoModuleCompile             = "timer_rego_module_compile_ns"
        /// 服务器处理总耗时 (ns)
        case timerServerHandler                 = "timer_server_handler_ns"
        /// 服务器查询缓存命中计数
        case counterServerQueryCacheHit         = "counter_server_query_cache_hit"
    }
}
