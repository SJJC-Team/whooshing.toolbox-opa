import ErrorHandle

public extension OPA {
    enum Errcase: String, ErrList {
        case requestBuildFailed = "请求构建失败"
        case requestFailed = "向 OPA 请求时失败"
        case responseParseFailed = "OPA 响应内容解析失败"
        case badRequest = "请求不合法"
        case badResponse = "OPA 响应内容不匹配"
        case shutdownFailed = "OPA 终止失败"
    }
}
