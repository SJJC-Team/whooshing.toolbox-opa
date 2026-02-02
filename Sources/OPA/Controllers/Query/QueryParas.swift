public extension OPA.QueryController {
    struct SimpleQueryParameter: OPA.QueryParameter {
        public let pretty: Bool
        
        public init(
            pretty: Bool = false
        ) {
            self.pretty = pretty
        }
    }
    
    struct DataQueryParameter: OPA.QueryParameter {
        public let pretty: Bool
        public let provenance: Bool
        public let explain: OPA.Explain
        public let metrics: Bool
        public let instrument: Bool
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
    
    struct AdhocQueryParameter: OPA.QueryParameter {
        public let pretty: Bool
        public let explain: OPA.Explain
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
