public extension OPA.PolicyController {
    struct GetQueryParameter: OPA.QueryParameter {
        public let pretty: Bool
        
        public init(
            pretty: Bool = false
        ) {
            self.pretty = pretty
        }
    }
    
    typealias DeleteQueryParameter = SaveQueryParameter
    
    struct SaveQueryParameter: OPA.QueryParameter {
        public let pretty: Bool
        public let metrics: Bool
        
        public init(
            pretty: Bool = false,
            metrics: Bool = false
        ) {
            self.pretty = pretty
            self.metrics = metrics
        }
    }
}
