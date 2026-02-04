import LoggingAdvanced

public extension OPA.DataController {
    /// 数据获取参数
    struct GetQueryParameter: OPA.QueryParameter {
        /// 是否美化输出 (Pretty Print)
        public let pretty: Bool
        /// 是否返回来源信息 (Provenance)
        public let provenance: Bool
        /// 决策解释级别 (Trace)
        public let explain: OPA.Explain
        /// 是否返回性能指标 (Metrics)
        public let metrics: Bool
        /// 是否开启性能检测 (Instrument)
        public let instrument: Bool
        /// 是否对内建函数错误严格处理 (Strict Built-in Errors)
        public let strictBuiltinErrors: Bool
        
        enum CodingKeys: String, CodingKey {
            case pretty
            case provenance
            case explain
            case metrics
            case instrument
            case strictBuiltinErrors = "strict-builtin-errors"
        }
        
        public init(
            pretty: Bool = false,
            provenance: Bool = false,
            explain: OPA.Explain = .off,
            metrics: Bool = false,
            instrument: Bool = false,
            strictBuiltinErrors: Bool = true
        ) {
            self.pretty = pretty
            self.provenance = provenance
            self.explain = explain
            self.metrics = metrics
            self.instrument = instrument
            self.strictBuiltinErrors = strictBuiltinErrors
        }
    }
    
    typealias DeleteQueryParameter = SaveQueryParameter
    
    /// 数据保存参数
    struct SaveQueryParameter: OPA.QueryParameter {
        /// 是否返回性能指标
        public let metrics: Bool
        
        public init(
            metrics: Bool = false
        ) {
            self.metrics = metrics
        }
    }
}

extension OPA.DataController.GetQueryParameter: Loggerable, CustomStringConvertible {
    public var description: String {
        "pretty=\(pretty), provenance=\(provenance), explain=\(explain.rawValue), metrics=\(metrics), instrument=\(instrument), strictBuiltinErrors=\(strictBuiltinErrors)"
    }
}

extension OPA.DataController.SaveQueryParameter: Loggerable, CustomStringConvertible {
    public var description: String {
        "metrics=\(metrics)"
    }
}
