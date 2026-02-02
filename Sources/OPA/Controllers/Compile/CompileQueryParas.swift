public extension OPA.CompileController {
    struct QueryParameter: OPA.QueryParameter {
        public let pretty: Bool
        public let explain: OPA.Explain
        public let metrics: Bool
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
