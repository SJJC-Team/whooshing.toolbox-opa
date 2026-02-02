public extension OPA {
    struct Err: Codable, Error, Sendable {
        public let code: String
        public let message: String
        public let errors: [Self]?
        public let location: Location?
    }
    
    struct Warning: Codable, Error, Sendable {
        public let code: String
        public let message: String
        public let location: Location?
    }
    
    struct Location: Codable, Sendable {
        public let file: String
        public let row: Int
        public let col: Int
    }
}

extension OPA.Err: CustomStringConvertible {
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

extension OPA.Warning: CustomStringConvertible {
    public var description: String {
        desc(head: true)
    }
    
    public func desc(head: Bool) -> String {
        var desc = (head ? "OPA.Warning: " : "") + "[\(code)] \(message)"
        
        if let loc = location {
            desc += " AT: \(loc.file):\(loc.row):\(loc.col)"
        }
        
        return desc
    }
}
