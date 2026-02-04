import LoggingAdvanced

public extension OPA {
    /// OPA 错误结构体
    ///
    /// 表示从 OPA 返回的错误信息，包含错误码、消息以及位置信息。
    struct Err: Codable, Error, Sendable {
        /// 错误代码
        public let code: String
        /// 错误详细描述
        public let message: String
        /// 嵌套的错误列表
        public let errors: [Self]?
        /// 错误发生的位置
        public let location: Location?
    }
    
    /// OPA 警告结构体
    ///
    /// 表示从 OPA 返回的警告信息。
    struct Warning: Codable, Error, Sendable {
        /// 警告代码
        public let code: String
        /// 警告详细描述
        public let message: String
        /// 警告发生的位置
        public let location: Location?
    }
    
    /// 代码位置信息
    struct Location: Codable, Sendable {
        /// 文件名
        public let file: String
        /// 行号
        public let row: Int
        /// 列号
        public let col: Int
    }
}

extension OPA.Err: Loggerable, CustomStringConvertible {
    public var description: String {
        desc(head: true)
    }
    
    public func desc(head: Bool) -> String {
        var desc = (head ? "OPA.Error: " : "") + "[\(code)] \(message)"
        
        if let loc = location {
            desc += " AT: \(loc.file):\(loc.row):\(loc.col)"
        }
        
        if let subErrors = errors, !subErrors.isEmpty {
            let subDesc = subErrors.map { $0.desc(head: false) }.joined(separator: ", ")
            desc += " { \(subDesc) }"
        }
        
        return desc
    }
}

extension OPA.Warning: Loggerable, CustomStringConvertible {
    public var description: String {
        var desc = "[\(code)] \(message)"
        
        if let loc = location {
            desc += " AT: \(loc.file):\(loc.row):\(loc.col)"
        }
        
        return desc
    }
}
