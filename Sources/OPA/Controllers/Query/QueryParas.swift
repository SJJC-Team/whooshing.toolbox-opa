import LoggingAdvanced

public extension OPA.QueryController {
    /// 简单查询参数
    struct SimpleQueryParameter: OPA.QueryParameter {
        /// 是否美化输出
        public let pretty: Bool
        
        public init(pretty: Bool = false) {
            self.pretty = pretty
        }
    }
    
    /// 数据查询参数
    struct DataQueryParameter: OPA.QueryParameter {
        /// 是否美化输出 (Pretty Print)
        public let pretty: Bool
        /// 是否返回来源信息 (Provenance)
        ///
        /// 如果为 true，响应中将包含 `provenance` 字段，显示构建版本等信息。
        public let provenance: Bool
        /// 解释级别
        ///
        /// 控制返回的解释信息的详细程度 (Trace)。
        public let explain: OPA.Explain
        /// 是否返回性能指标 (Metrics)
        public let metrics: Bool
        /// 是否开启性能检测 (Instrument)
        ///
        /// 启用后，响应中将包含更详细的直方图统计数据。
        public let instrument: Bool
        /// 是否严格处理内建函数错误
        ///
        /// 如果为 true，当内建函数发生错误时，将直接返回错误而不是 undefined。
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
    
    /// Ad-hoc 查询参数
    struct AdhocQueryParameter: OPA.QueryParameter {
        /// 是否美化输出
        public let pretty: Bool
        /// 解释级别
        public let explain: OPA.Explain
        /// 是否返回性能指标
        public let metrics: Bool
        
        public init(
            pretty: Bool = false,
            explain: OPA.Explain = .off,
            metrics: Bool = false
        ) {
            self.pretty = pretty
            self.explain = explain
            self.metrics = metrics
        }
    }
}

extension OPA.QueryController.SimpleQueryParameter: Loggerable, CustomStringConvertible {
    public var description: String {
        "pretty=\(pretty)"
    }
}

extension OPA.QueryController.DataQueryParameter: Loggerable, CustomStringConvertible {
    public var description: String {
        "pretty=\(pretty), provenance=\(provenance), explain=\(explain.rawValue), metrics=\(metrics), instrument=\(instrument), strictBuiltinErrors=\(strictBuiltinErrors)"
    }
}

extension OPA.QueryController.AdhocQueryParameter: Loggerable, CustomStringConvertible {
    public var description: String {
        "pretty=\(pretty), explain=\(explain.rawValue), metrics=\(metrics)"
    }
}
