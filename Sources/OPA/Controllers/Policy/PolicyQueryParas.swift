public extension OPA.PolicyController {
    /// 策略获取参数
    struct GetQueryParameter: OPA.QueryParameter {
        /// 是否美化输出
        public let pretty: Bool
        
        public init(
            pretty: Bool = false
        ) {
            self.pretty = pretty
        }
    }
    
    typealias DeleteQueryParameter = SaveQueryParameter
    
    /// 策略保存参数
    struct SaveQueryParameter: OPA.QueryParameter {
        /// 是否美化输出
        public let pretty: Bool
        /// 是否返回性能指标
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
