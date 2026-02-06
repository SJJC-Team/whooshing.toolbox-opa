import Logging
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
    
    /// OPA 提示结构体
    ///
    /// 表示从 OPA 返回的提示信息。
    struct Hint: Codable, Error, Sendable {
        /// 提示详细描述
        public let message: String
        /// 提示发生的位置
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

// MARK: - Err Description
extension OPA.Err: Loggerable, CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["code: \(code)", "message: \(message)"]
        
        // 处理位置信息
        if let location = location {
            parts.append("location: {\(location)}")
        }
        
        // 处理递归嵌套错误 (errors)
        if let nestedErrors = errors, !nestedErrors.isEmpty {
            let nestedDesc = nestedErrors.map { "{\($0)}" }.joined(separator: ", ")
            parts.append("errors: [\(nestedDesc)]")
        }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Warning Description
extension OPA.Warning: Loggerable, CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["code: \(code)", "message: \(message)"]
        if let location = location {
            parts.append("location: {\(location)}")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Warning Description
extension OPA.Hint: Loggerable, CustomStringConvertible {
    public var description: String {
        var parts: [String] = ["message: \(message)"]
        if let location = location {
            parts.append("location: {\(location)}")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Location Description
extension OPA.Location: Loggerable, CustomStringConvertible {
    public var description: String {
        "file: \(file), row: \(row), col: \(col)"
    }
}
