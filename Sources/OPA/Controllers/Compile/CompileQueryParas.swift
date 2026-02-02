public extension OPA.CompileController {
    /// 编译查询参数
    struct QueryParameter: OPA.QueryParameter {
        /// 是否美化输出
        public let pretty: Bool
        /// 解释级别
        public let explain: OPA.Explain
        /// 是否返回性能指标
        public let metrics: Bool
        /// 是否开启性能检测
        public let instrument: Bool
        
        public init(
            pretty: Bool = false,
            explain: OPA.Explain = .off,
            metrics: Bool = false,
            instrument: Bool = false,
        ) {
            self.pretty = pretty
            self.explain = explain
            self.metrics = metrics
            self.instrument = instrument
        }
    }
}
