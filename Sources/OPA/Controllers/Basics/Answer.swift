import Foundation
import ErrorHandle
import LoggingAdvanced
import Logging
@preconcurrency import AnyCodable

public extension OPA {
    /// OPA API 响应通用包装器
    ///
    /// 所有 OPA API 的响应通常都包含在一个 result 字段中，并附带度量信息、决策 ID 等元数据。
    struct Answer<T: Decodable & Sendable>: Decodable, Sendable {
        /// API 调用的主要结果
        public let result: T
        /// 提示信息列表
        public let hints: [Hint]?
        /// 警告信息列表
        public let warnings: [Warning]?
        /// 决策 ID (用于审计和追踪)
        ///
        /// 每个决策请求的唯一标识符。如果请求中包含 `provenance=true`，则此字段对于追踪决策来源非常有用。
        public let decisionId: String?
        /// 性能度量指标
        ///
        /// 包含详细的性能计时器、计数器等信息。需要请求参数中 `metrics=true`。
        public let metrics: Metrics?
        /// 解释信息 (仅当请求中启用了 explain 时存在)
        ///
        /// 包含决策过程的详细解释，用于调试为什么决策结果是 true 或 false。
        public let explanation: [AnyCodable]?
        
        /// 来源信息 (Provenance)
        ///
        /// 包含构建时的版本、提交信息、时间戳以及加载的 bundle 信息。
        public let provenance: Provenance?

        enum CodingKeys: String, CodingKey {
            case result, hints, warnings, metrics, explanation, provenance
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

            self.hints = try container.decodeIfPresent([Hint].self, forKey: .hints)
            self.warnings = try container.decodeIfPresent([Warning].self, forKey: .warnings)
            self.decisionId = try container.decodeIfPresent(String.self, forKey: .decisionId)
            self.provenance = try container.decodeIfPresent(Provenance.self, forKey: .provenance)
            self.metrics = try container.decodeIfPresent(Metrics.self, forKey: .metrics)
            self.explanation = try container.decodeIfPresent([AnyCodable].self, forKey: .explanation)
        }
        
        init(
            result: T,
            hints: [Hint]? = nil,
            warnings: [Warning]? = nil,
            decisionId: String? = nil,
            metrics: Metrics? = nil,
            explanation: [AnyCodable]? = nil,
            provenance: Provenance? = nil
        ) {
            self.result = result
            self.hints = hints
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
        
        func logHintsIfHas(
            label: Logger.Message,
            logger: Logger,
            file: String = #fileID,
            function: String = #function,
            line: UInt = #line
        ) {
            if let hints = self.hints {
                logger.warnings(
                    "\(label)提示",
                    paras: hints.map { (["hint": .data($0)], nil) },
                    file: file,
                    function: function,
                    line: line
                )
            }
            
            if let warns = self.warnings {
                logger.warnings(
                    "\(label)警告",
                    paras: warns.map { (["warning": .data($0)], nil) },
                    file: file,
                    function: function,
                    line: line
                )
            }
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
        
        if let hints = hints {
            info.append("hints=\(hints)")
        }
        
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
