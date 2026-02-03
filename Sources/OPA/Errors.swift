import ErrorHandle

public extension OPA {
    /// OPA 客户端内部错误枚举
    ///
    /// 涵盖了从请求构建、网络传输到响应解析等各环节可能出现的错误。
    enum Errcase: String, ErrList {
        case requestBuildFailed = "请求构建失败"
        case requestFailed = "向 OPA 请求时失败"
        case responseParseFailed = "OPA 响应内容解析失败"
        case badRequest = "请求不合法"
        case badResponse = "OPA 响应内容不匹配"
        case shutdownFailed = "OPA 终止失败"
    }
}
