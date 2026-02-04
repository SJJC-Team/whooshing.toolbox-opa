import Foundation
import ErrorHandle
import LoggingAdvanced
@preconcurrency import AnyCodable

public extension OPA {
    /// OPA API 响应通用包装器
    ///
    /// 所有 OPA API 的响应通常都包含在一个 result 字段中，并附带度量信息、决策 ID 等元数据。
    struct Answer<T: Decodable & Sendable>: Decodable, Sendable {
        /// API 调用的主要结果
        public let result: T
        /// 警告信息列表
        public let warnings: [Warning]?
        /// 决策 ID (用于审计和追踪)
        public let decisionId: String?
        /// 性能度量指标
        public let metrics: Metrics?
        /// 解释信息 (仅当请求中启用了 explain 时存在)
        public let explanation: [AnyCodable]?
        
        public let provenance: Provenance?

        enum CodingKeys: String, CodingKey {
            case result, warnings, metrics, explanation, provenance
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
            self.provenance = try container.decodeIfPresent(Provenance.self, forKey: .provenance)
            self.metrics = try container.decodeIfPresent(Metrics.self, forKey: .metrics)
            self.explanation = try container.decodeIfPresent([AnyCodable].self, forKey: .explanation)
        }
        
        init(
            result: T,
            warnings: [Warning]? = nil,
            decisionId: String? = nil,
            metrics: Metrics? = nil,
            explanation: [AnyCodable]? = nil,
            provenance: Provenance? = nil
        ) {
            self.result = result
            self.warnings = warnings
            self.decisionId = decisionId
            self.metrics = metrics
            self.explanation = explanation
            self.provenance = provenance
        }

        func set<G: Decodable & Sendable>(result: G) -> Answer<G> {
            .init(
                result: result,
                warnings: warnings,
                decisionId: decisionId,
                metrics: metrics,
                explanation: explanation
            )
        }
    }
    
    struct Provenance: Codable, Sendable {
        let buildCommit: String
        let buildHost: String?
        let buildTimestamp: String
        let bundles: [String: Bundle]?
        let version: String
        
        enum CodingKeys: String, CodingKey {
            case buildCommit = "build_commit"
            case buildHost = "build_host"
            case buildTimestamp = "build_timestamp"
            case bundles = "bundles"
            case version = "version"
        }
        
        struct Bundle: Codable, Sendable {
            let revision: String
        }
    }
    
    struct NULL: Codable, Sendable, CustomStringConvertible, Loggerable {
        public init() {}
        
        public init(from decoder: any Decoder) throws {
            let coder = try decoder.singleValueContainer()
            guard coder.decodeNil() else {
                throw Errcase.codableParseFailed.d(category: .internal).metadata(["type": "NULL"])
            }
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
        
        public var description: String { "null" }
    }
}

extension OPA.Answer: Loggerable, CustomStringConvertible {
    public var description: String {
        var info: [String] = []

        if let dId = decisionId {
            info.append("id=\(dId)")
        }
        
        let resDesc = (result as? CustomStringConvertible)?.description ?? "\(result)"
        info.append("result=\(resDesc)")
        
        if let warnings = warnings {
            info.append("warnings=\(warnings)")
        }
        
        if let metrics = metrics {
            info.append("metrics=[\(metrics)]")
        }
        
        if let explanation = explanation {
            info.append("explanation=\(explanation)")
        }
        
        return info.joined(separator: "; ")
    }
}
