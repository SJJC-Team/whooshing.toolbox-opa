import AsyncHTTPClient
import NIOCore
import NIOAdvanced
import NIOHTTP1
import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public extension OPA {
    protocol Controller: Sendable, AnyObject {
        var argument: OPA.ConnectionArgument { get }
    }
    
    struct SingleResult<T: Decodable & Sendable>: Decodable, Sendable {
        let result: T?
    }
    
    struct Response: Sendable {
        private let res: HTTPClient.Response
        
        fileprivate init(res: HTTPClient.Response) {
            self.res = res
        }
        
        var status: HTTPResponseStatus { res.status }
        
        func plain() -> Res<String, OPA.Errcase> {
            guard
                let contentType = res.headers.first(name: "Content-Type")?.lowercased(),
                let body = res.body
            else {
                return .failure(OPA.Errcase.badResponse.d("预期从 OPA 得到 String，却得到空响应体", category: .external))
            }
            
            guard contentType == "text/plain" else {
                return .failure(OPA.Errcase.badResponse.d("预期 OPA 响应体为 \"text/plain\"，却得到 \(log: contentType)", category: .external))
            }
            
            guard let plain = body.getString(at: body.readerIndex, length: body.readableBytes) else {
                return .failure(OPA.Errcase.responseParseFailed.d("将返回体解码为 String 时失败", category: .internal))
            }
            return .success(plain)
        }
        
        func json<T>(as: T.Type = T.self) -> Res<T, OPA.Errcase> where T: Decodable & Sendable {
            guard
                let contentType = res.headers.first(name: "Content-Type")?.lowercased(),
                let body = res.body
            else {
                return .failure(OPA.Errcase.badResponse.d("预期从 OPA 得到 Json，却得到空响应体", category: .external))
            }
            
            guard contentType == "application/json" else {
                return .failure(OPA.Errcase.badResponse.d("预期 OPA 响应体为 \"application/json\"，却得到 \(log: contentType)", category: .external))
            }
            
            return .init(throws: OPA.Errcase.responseParseFailed, "将响应体反序列化为 \(String(describing: T.self)) 类型失败", category: .internal) {
                try JSONDecoder().decode(T.self, from: body)
            }
        }
    }
}

public extension OPA {
    enum PatchOperation: Encodable, Sendable {
        case add(path: String, value: AnyCodable)
        case remove(path: String)
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

extension OPA {
    struct Err: Codable, Error, Sendable {
        let code: String
        let message: String
        let errors: [Self]?
        let location: Location?
        
        struct Location: Codable, Sendable {
            let file: String
            let row: Int
            let col: Int
        }
    }
}

extension OPA.Err: CustomStringConvertible {
    public var description: String {
        desc(head: true)
    }
    
    public func desc(head: Bool) -> String {
        // 1. 基础错误码和消息
        var desc = (head ? "OPA.Error: " : "") + "[\(code)] \(message)"
        
        // 2. 位置信息简写 (file:row:col)
        if let loc = location {
            desc += " AT: \(loc.file):\(loc.row):\(loc.col)"
        }
        
        // 3. 嵌套错误处理 (递归拉平到一行)
        if let subErrors = errors, !subErrors.isEmpty {
            let subDesc = subErrors.map { $0.desc(head: false) }.joined(separator: ", ")
            desc += " { \(subDesc) }"
        }
        
        return desc
    }
}

extension OPA.Controller {
    var eventLoop: EventLoop { argument.eventLoop }
    var client: HTTPClient { argument.client }
    var url: String { argument.url }
    
    func send(
        uri: String,
        queries: [URLQueryItem] = [],
        method: HTTPMethod,
        extraHeaders: [String: String] = [:],
        body: String? = nil,
        validStatusCode: Set<HTTPResponseStatus> = [.ok],
        errorStatusCode: [HTTPResponseStatus: (String, OPA.Errcase.ErrType.Category)] = [:]
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
        
        return __send(req: req, validStatusCode: validStatusCode, errorStatusCode: errorStatusCode)
    }
    
    func send<T: Encodable & Sendable>(
        uri: String,
        queries: [URLQueryItem] = [],
        method: HTTPMethod,
        extraHeaders: [String: String] = [:],
        body: T? = nil,
        validStatusCode: Set<HTTPResponseStatus> = [.ok],
        errorStatusCode: [HTTPResponseStatus: (String, OPA.Errcase.ErrType.Category)] = [:]
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
                        try required(throws: OPA.Errcase.requestBuildFailed, "从 \(String(describing: T.self)) 类型 JSON 序列化失败", category: .external) {
                            ByteBuffer(data: try JSONEncoder().encode(body!))
                        }
                )
            )
        }
        
        return __send(req: req, validStatusCode: validStatusCode, errorStatusCode: errorStatusCode)
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
        validStatusCode: Set<HTTPResponseStatus>,
        errorStatusCode: [HTTPResponseStatus: (String, OPA.Errcase.ErrType.Category)]
    ) -> EventLoopRes<OPA.Response, OPA.Errcase> {
        eventLoop.makeResultWithTask { () throws(OPA.Errcase.ErrType) in
            try req.get()
        }.flatMap { req in
            self.client.execute(request: req)
                .withError(OPA.Errcase.requestFailed, category: .internal)
        }.flatMap { res in
            if let errors = errorStatusCode[res.status] {
                return self.eventLoop.makeFailedResult(makeError(msg: errors.0, category: errors.1))
            } else if !validStatusCode.contains(res.status) {
                return self.eventLoop.makeFailedResult(makeError(msg: nil, category: .internal))
            } else {
                return self.eventLoop.makeSucceededResult(.init(res: res))
            }
            
            func makeError(msg: String?, category: OPA.Errcase.ErrType.Category) -> OPA.Errcase.ErrType {
                let error: OPA.Err?
                if let body = res.body {
                    error = try? JSONDecoder().decode(OPA.Err.self, from: body)
                } else {
                    error = nil
                }
                return OPA.Errcase.requestFailed.d(msg ?? "OPA 返回非预期状态码: \(res.status)", category: category).subErr(error)
            }
        }
    }
}
