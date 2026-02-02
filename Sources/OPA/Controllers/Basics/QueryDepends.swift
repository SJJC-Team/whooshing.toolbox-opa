import Foundation

public extension OPA {
    enum Explain: String, Codable, Sendable {
        case off, full, debug, notes, fails
    }
    
    protocol QueryParameter: Codable, Sendable {
        var queryItems: [URLQueryItem] { get }
    }
}

extension OPA.QueryParameter {
    public var queryItems: [URLQueryItem] {
        guard
            let data = try? JSONEncoder().encode(self),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return []
        }
        
        return json.compactMap { key, value in
            let stringValue: String
            
            if let boolValue = value as? Bool {
                stringValue = boolValue ? "true" : "false"
            } else if let boolValue = value as? NSNumber, CFGetTypeID(boolValue) == CFBooleanGetTypeID() {
                stringValue = boolValue.boolValue ? "true" : "false"
            } else {
                stringValue = "\(value)"
            }
            
            return URLQueryItem(name: key, value: stringValue)
        }
    }
}
