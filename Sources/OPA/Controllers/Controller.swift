import AsyncHTTPClient
import NIOCore
import NIOAdvanced
import NIOHTTP1
import Foundation
import ErrorHandle
import AnyCodable

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
        
        func json<T>() -> Res<T, OPA.Errcase> where T: Decodable & Sendable {
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
        validStatusCode: [HTTPResponseStatus] = [.ok]
    ) -> EventLoopRes<OPA.Response, OPA.Errcase> {
        let req = Res<HTTPClient.Request, OPA.Errcase>(throws: OPA.Errcase.requestBuildFailed, category: .internal) {
            try HTTPClient.Request(
                url: combineURL(uri: uri, queries: queries),
                method: method,
                headers: .init(
                    [
                        ("Content-Type", "text/plain")
                    ] +
                    Array(extraHeaders)
                ),
                body: .byteBuffer(ByteBuffer(string: body ?? ""))
            )
        }
        
        return __send(req: req, validStatusCode: validStatusCode)
    }
    
    func send<T: Encodable & Sendable>(
        uri: String,
        queries: [URLQueryItem] = [],
        method: HTTPMethod,
        extraHeaders: [String: String] = [:],
        body: T? = nil,
        validStatusCode: [HTTPResponseStatus] = [.ok]
    ) -> EventLoopRes<OPA.Response, OPA.Errcase> {
        let req = Res<HTTPClient.Request, OPA.Errcase>(throws: OPA.Errcase.requestBuildFailed, category: .internal) {
            try HTTPClient.Request(
                url: combineURL(uri: uri, queries: queries),
                method: method,
                headers: .init(
                    [
                        ("Content-Type", "application/json")
                    ] +
                    Array(extraHeaders)
                ),
                body: .byteBuffer(
                    body == nil ?
                        ByteBuffer() :
                        try required(throws: OPA.Errcase.requestBuildFailed, "从 \(String(describing: T.self)) 类型 JSON 序列化失败", category: .external) {
                            ByteBuffer(data: try JSONEncoder().encode(body!))
                        }
                )
            )
        }
        
        return __send(req: req, validStatusCode: validStatusCode)
    }
    
    func combineURL(
        uri: String,
        queries: [URLQueryItem]
    ) -> String {
        var components = URLComponents(string: url + uri)
        
        components?.queryItems = queries
        
        return components?.url?.absoluteString ?? ""
    }
    
    func __send(
        req: Res<HTTPClient.Request, OPA.Errcase>,
        validStatusCode: [HTTPResponseStatus]
    ) -> EventLoopRes<OPA.Response, OPA.Errcase> {
        eventLoop.makeResultWithTask { () throws(OPA.Errcase.ErrType) in
            try req.get()
        }.flatMap { req in
            self.client.execute(request: req)
                .withError(OPA.Errcase.requestFailed, category: .internal)
        }.flatMapThrowing { res throws(OPA.Errcase.ErrType) in
            guard (validStatusCode.contains { $0 == res.status }) else {
                let error: OPA.Err?
                if let body = res.body {
                    error = try? JSONDecoder().decode(OPA.Err.self, from: body)
                } else {
                    error = nil
                }
                throw OPA.Errcase.requestFailed.d("OPA 返回非预期状态码: \(res.status)", category: .internal).subErr(error)
            }
            
            return .init(res: res)
        }
    }
}
