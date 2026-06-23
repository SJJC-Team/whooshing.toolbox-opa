import NIOAdvanced
import Foundation
import AsyncHTTPClient
import NIOHTTP1
@preconcurrency import AnyCodable

public extension OPA {
    /// 基础控制器协议
    ///
    /// 所有 OPA 功能控制器都应遵守此协议，提供基础的连接参数。
    protocol Controller: Sendable, AnyObject {
        /// OPA 连接参数
        var argument: OPA.ConnectionArgument { get }
        /// 用于记录日志的 Logger 实例
        var logger: Logger { get }
    }
    
    /// HTTP 响应封装结构体
    ///
    /// 封装了底层的 HTTPClient.Response，提供便捷的方法来提取 Body 内容。
    struct Response: Sendable {
        private let res: HTTPClient.Response
        private let logger: Logger
        
        fileprivate init(res: HTTPClient.Response, logger: Logger) {
            self.res = res
            self.logger = logger
        }
        
        /// 获取 HTTP 状态码
        var status: HTTPResponseStatus { res.status }
        
        /// 尝试将响应体解析为纯文本字符串
        ///
        /// - Returns: `Res<String, OPA.Errcase>` 包含字符串结果或错误
        func plain() -> Res<String, OPA.Errcase> {
            logger.debug("从响应体中提取内容", metadata: ["contentType": "text/plain", "body": .string(res.body == nil ? "0" : "\(res.body!.readableBytes)bytes")])
            
            guard
                let contentType = res.headers.first(name: "Content-Type")?.lowercased(),
                let body = res.body
            else {
                return .failure(OPA.Errcase.badResponse.d("预期从 OPA 得到 String，却得到空响应体", category: .external()))
            }
            
            guard contentType == "text/plain" else {
                return .failure(OPA.Errcase.badResponse.d("OPA 响应体格式非预期，预期为 text/plain", category: .external()).metadata(["from": "\(contentType)"]))
            }
            
            guard let plain = body.getString(at: body.readerIndex, length: body.readableBytes) else {
                return .failure(OPA.Errcase.responseParseFailed.d("将返回体解码为 String 时失败", category: .internal))
            }
            
            logger.debug("从响应体中提取成功")
            
            return .success(plain)
        }
        
        /// 尝试将响应体解析为 JSON 对象
        ///
        /// - Parameters:
        ///   - as: 目标类型
        ///   - accept: 预期的 Content-Type，默认为 `application/json`
        /// - Returns: `Res<T, OPA.Errcase>` 包含解码后的对象或错误
        func json<T>(
            as: T.Type = T.self,
            accept: String = "application/json"
        ) -> Res<T, OPA.Errcase> where T: Decodable & Sendable {
            logger.debug("从响应体中提取内容", metadata: ["contentType": .string(accept), "body": .string(res.body == nil ? "0" : "\(res.body!.readableBytes)bytes")])
            
            guard
                let contentType = res.headers.first(name: "Content-Type")?.lowercased(),
                let body = res.body
            else {
                return .failure(OPA.Errcase.badResponse.d("预期从 OPA 得到 Json，却得到空响应体", category: .external()))
            }
            
            guard contentType == accept else {
                return .failure(OPA.Errcase.badResponse.d("预期 OPA 响应体为 \(log: accept)，却得到 \(log: contentType)", category: .external()))
            }
            
            return .init(throws: OPA.Errcase.responseParseFailed, "将响应体反序列化为 \(String(describing: T.self)) 类型失败", category: .internal) {
                let res = try JSONDecoder().decode(T.self, from: body)
                logger.debug("从响应体中提取成功")
                return res
            }
        }
    }
}

public extension OPA {
    /// JSON Patch 操作定义
    ///
    /// 遵循 RFC 6902 标准，用于对 OPA 数据进行增量更新。
    enum PatchOperation: Encodable, Sendable {
        /// 添加操作
        case add(path: String, value: AnyCodable)
        /// 移除操作
        case remove(path: String)
        /// 替换操作
        case replace(path: String, value: AnyCodable)

        private enum CodingKeys: String, CodingKey {
            case op, path, value, from
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .add(let path, let value):
                try container.encode("add", forKey: .op)
                try container.encode(path, forKey: .path)
                try container.encode(value, forKey: .value)
            case .remove(let path):
                try container.encode("remove", forKey: .op)
                try container.encode(path, forKey: .path)
            case .replace(let path, let value):
                try container.encode("replace", forKey: .op)
                try container.encode(path, forKey: .path)
                try container.encode(value, forKey: .value)
            }
        }
    }
}

extension OPA.PatchOperation: CustomStringConvertible, Loggerable {
    // MARK: - CustomStringConvertible
    /// 符合标准的可读描述（常用于 print 或默认字符串插值）
    public var description: String {
        switch self {
        case .add(let path, let value):
            return "add '\(path)' with \(value)"
        case .remove(let path):
            return "remove '\(path)'"
        case .replace(let path, let value):
            return "replace '\(path)' with \(value)"
        }
    }
    
    /// 摘要日志：只关注操作类型和路径，不关心里面的大数据 value
    @inlinable
    public var summaryDescription: String {
        switch self {
        case .add(let path, _):
            return "add(\(path))"
        case .remove(let path):
            return "remove(\(path))"
        case .replace(let path, _):
            return "replace(\(path))"
        }
    }
}

extension OPA.Controller {
    var eventLoop: EventLoop { argument.eventLoop }
    var client: HTTPClient { argument.client }
    var url: String { argument.url }
    
    func getRequestLogger() -> Logger {
        self.logger.derive(metadata: ["request-id": .stringConvertible(UUID())])
    }
    
    func send(
        uri: String,
        queries: [URLQueryItem] = [],
        method: HTTPMethod,
        extraHeaders: [String: String] = [:],
        body: String? = nil,
        logger: Logger,
        validStatusCode: Set<HTTPResponseStatus> = [.ok],
        errorStatusCode: [HTTPResponseStatus: (String, ErrCategory)] = [:]
    ) -> EventLoopRes<OPA.Response, OPA.Errcase> {
        var headers: HTTPHeaders = ["Content-Type": "text/plain"]
        
        for (name, value) in extraHeaders {
            headers.replaceOrAdd(name: name, value: value)
        }
        
        let req = Res<HTTPClient.Request, OPA.Errcase>(throws: OPA.Errcase.requestBuildFailed, category: .internal) {
            try HTTPClient.Request(
                url: combineURL(uri: uri, queries: queries),
                method: method,
                headers: headers,
                body: .byteBuffer(ByteBuffer(string: body ?? ""))
            )
        }
        
        return __send(req: req, logger: logger, validStatusCode: validStatusCode, errorStatusCode: errorStatusCode)
    }
    
    func send<T: Encodable & Sendable>(
        uri: String,
        queries: [URLQueryItem] = [],
        method: HTTPMethod,
        extraHeaders: [String: String] = [:],
        body: T? = nil,
        logger: Logger,
        validStatusCode: Set<HTTPResponseStatus> = [.ok],
        errorStatusCode: [HTTPResponseStatus: (String, ErrCategory)] = [:]
    ) -> EventLoopRes<OPA.Response, OPA.Errcase> {
        var headers: HTTPHeaders = ["Content-Type": "application/json"]
        
        for (name, value) in extraHeaders {
            headers.replaceOrAdd(name: name, value: value)
        }
        
        let req = Res<HTTPClient.Request, OPA.Errcase>(throws: OPA.Errcase.requestBuildFailed, category: .internal) {
            try HTTPClient.Request(
                url: combineURL(uri: uri, queries: queries),
                method: method,
                headers: headers,
                body: .byteBuffer(
                    body == nil ?
                        ByteBuffer() :
                        try required(throws: OPA.Errcase.requestBuildFailed, "JSON 序列化失败", metadata: ["from": "\(T.self)"], category: .external()) {
                            ByteBuffer(data: try JSONEncoder().encode(body!))
                        }
                )
            )
        }
        
        return __send(req: req, logger: logger, validStatusCode: validStatusCode, errorStatusCode: errorStatusCode)
    }
    
    func combineURL(
        uri: String,
        queries: [URLQueryItem]
    ) -> String {
        var components = URLComponents(string: url + uri)
        
        guard queries.count > 0 else {
            return components?.url?.absoluteString ?? ""
        }
        
        components?.queryItems = queries
        
        return components?.url?.absoluteString ?? ""
    }
    
    func __send(
        req: Res<HTTPClient.Request, OPA.Errcase>,
        logger: Logger,
        validStatusCode: Set<HTTPResponseStatus>,
        errorStatusCode: [HTTPResponseStatus: (String, ErrCategory)]
    ) -> EventLoopRes<OPA.Response, OPA.Errcase> {
        eventLoop.makeResultWithTask { () throws(OPA.Errcase.ErrType) in
            let r = try req.get()
            logger.debug("请求已建立，准备发送", metadata: ["req": .data(r)])
            return r
        }.flatMap { req in
            self.client.execute(request: req, logger: logger.derive(subId: "client"))
                .withError(OPA.Errcase.requestFailed, category: .internal)
        }.flatMap { res in
            logger.debug("收到 OPA 响应", metadata: ["res": .data(res), "status": .stringConvertible(res.status)])
            
            if let errors = errorStatusCode[res.status] {
                return self.eventLoop.makeFailedResult(makeError(msg: errors.0, category: errors.1))
            } else if !validStatusCode.contains(res.status) {
                return self.eventLoop.makeFailedResult(makeError(msg: nil, category: .internal))
            } else {
                let response = OPA.Response(res: res, logger: logger)
                logger.debug("响应处理成功")
                return self.eventLoop.makeSucceededResult(response)
            }
            
            func makeError(msg: String?, category: ErrCategory) -> OPA.Errcase.ErrType {
                let error: OPA.Err?
                if let body = res.body {
                    error = try? JSONDecoder().decode(OPA.Err.self, from: body)
                } else {
                    error = nil
                }
                return OPA.Errcase.requestFailed.d(msg ?? "OPA 返回非预期状态码", category: category).subErr(error).metadata(["status": .stringConvertible(res.status)])
            }
        }
    }
}

extension HTTPClient.Request: @retroactive Loggerable {
    public var logDescription: String {
        let urlPath = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        
        let headerCount = headers.count
        
        let bodySummary: String
        if let body = self.body {
            if let size = body.contentLength {
                bodySummary = "body=\(size)bytes"
            } else {
                bodySummary = "body=exists"
            }
        } else {
            bodySummary = "body=none"
        }
        
        return "\(method) \(urlPath)\(query) [Headers:\(headerCount)] body=\(bodySummary)"
    }
}

extension HTTPClient.Response: @retroactive Loggerable {
    public var logDescription: String {
        let statusStr = "\(status.code) \(status.reasonPhrase)"
        
        let headerCount = headers.count
        
        let bodySize = body?.readableBytes ?? 0
        let bodySummary = bodySize > 0 ? "\(bodySize)bytes" : "empty"
        
        return "\(statusStr) [Headers:\(headerCount)] body=\(bodySummary)"
    }
}
