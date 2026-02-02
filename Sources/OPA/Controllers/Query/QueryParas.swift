public extension OPA.QueryController {
    /// 简单查询参数
    struct SimpleQueryParameter: OPA.QueryParameter {
        /// 是否美化输出
        public let pretty: Bool
        
        public init(
            pretty: Bool = false
        ) {
            self.pretty = pretty
        }
    }
    
    /// 数据查询参数
    struct DataQueryParameter: OPA.QueryParameter {
        /// 是否美化输出
        public let pretty: Bool
        /// 是否返回来源信息
        public let provenance: Bool
        /// 解释级别
        public let explain: OPA.Explain
        /// 是否返回性能指标
        public let metrics: Bool
        /// 是否开启性能检测
        public let instrument: Bool
        /// 是否严格处理内建函数错误
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
