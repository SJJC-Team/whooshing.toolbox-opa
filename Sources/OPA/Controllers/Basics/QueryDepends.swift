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

public extension OPA.QueryParameter {
    var queryItems: [URLQueryItem] {
        guard
            let data = try? JSONEncoder().encode(self),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return []
        }
        
        return json.compactMap { key, value in
            let stringValue: String
            
            // 1. 优先尝试 Swift 原生 Bool
            if let boolValue = value as? Bool {
                stringValue = boolValue ? "true" : "false"
            } 
            // 2. 处理 NSNumber (处理从 JSONSerialization 出来的布尔值)
            else if let nsNumber = value as? NSNumber {
                #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
                // Apple 平台：利用 CoreFoundation 精确区分 Boolean 和 Integer
                if CFGetTypeID(nsNumber) == CFBooleanGetTypeID() {
                    stringValue = nsNumber.boolValue ? "true" : "false"
                } else {
                    stringValue = "\(nsNumber)"
                }
                #else
                // Linux 平台：检查底层类型编码码 (Type Encoding)
                // 'c' 代表 char (BOOL), 'B' 代表 C++ bool
                let typeChar = UnicodeScalar(UInt8(nsNumber.objCType.pointee))
                if typeChar == "c" || typeChar == "B" {
                    stringValue = nsNumber.boolValue ? "true" : "false"
                } else {
                    stringValue = "\(nsNumber)"
                }
                #endif
            } 
            // 3. 兜底处理 (String, Int, Double 等)
            else {
                stringValue = "\(value)"
            }
            
            return URLQueryItem(name: key, value: stringValue)
        }
    }
}