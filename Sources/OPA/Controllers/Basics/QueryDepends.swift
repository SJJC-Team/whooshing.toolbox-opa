import Foundation

public extension OPA {
    /// 解释级别
    ///
    /// 控制 OPA 返回的决策解释信息的详细程度。
    enum Explain: String, Codable, Sendable {
        /// 关闭解释
        case off
        /// 完整解释
        case full
        /// 调试信息
        case debug
        /// 仅笔记
        case notes
        /// 仅失败信息
        case fails
    }
    
    /// 查询参数协议
    ///
    /// 用于将结构体转换为 URL 查询参数。
    protocol QueryParameter: Codable, Hashable, Sendable {
        /// 转换为 URL 查询项列表
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
            } else if let boolValue = value as? NSNumber {
                stringValue = boolValue.boolValue ? "true" : "false"
            } else {
                stringValue = "\(value)"
            }
            
            return URLQueryItem(name: key, value: stringValue)
        }
    }
}
