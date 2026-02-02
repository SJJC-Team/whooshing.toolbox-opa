import ErrorHandle

public extension OPA {
    /// OPA 客户端内部错误枚举
    ///
    /// 涵盖了从请求构建、网络传输到响应解析等各环节可能出现的错误。
    enum Errcase: String, ErrList {
        /// 请求构建失败 (如 URL 无效)
        case requestBuildFailed = "请求构建失败"
        /// 网络请求发送失败
        case requestFailed = "向 OPA 请求时失败"
        /// 响应内容解析错误
        case responseParseFailed = "OPA 响应内容解析失败"
        /// 请求参数错误 (400)
        case badRequest = "请求不合法"
        /// 响应内容类型不匹配
        case badResponse = "OPA 响应内容不匹配"
        /// 客户端关闭失败
        case shutdownFailed = "OPA 终止失败"
    }
}
