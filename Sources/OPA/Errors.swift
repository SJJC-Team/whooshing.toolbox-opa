import ErrorHandle

public extension OPA {
    /// OPA 客户端内部错误枚举
    ///
    /// 涵盖了从请求构建、网络传输到响应解析等各环节可能出现的错误。
    enum Errcase: String, ErrList {
        /// 构建 HTTP 请求时失败 (例如 URL 无效或 Body 序列化失败)
        case requestBuildFailed = "请求构建失败"
        /// 向 OPA 发送 HTTP 请求时发生网络错误或底层连接失败
        case requestFailed = "向 OPA 请求时失败"
        /// 无法解析 OPA 返回的响应体 (例如 JSON 格式错误)
        case responseParseFailed = "OPA 响应内容解析失败"
        /// 请求参数不合法 (通常对应 HTTP 400 错误)
        case badRequest = "请求不合法"
        /// OPA 返回的响应内容不符合预期 (例如 Content-Type 不匹配或缺少必要字段)
        case badResponse = "OPA 响应内容不匹配"
        /// 关闭 OPA 客户端时失败
        case shutdownFailed = "OPA 终止失败"
        /// Codable 编解码过程中发生的错误
        case codableParseFailed = "Codable 解析失败"
    }
}
