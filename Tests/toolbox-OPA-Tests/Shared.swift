import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
import Logging
import LoggingAdvanced
@testable import OPA
@preconcurrency import AnyCodable

struct TestingShared {
    
    enum TestStage {
        case data
        case policy
        case query
        case compile
        case examples
    }
    
    static let host = ProcessInfo.processInfo.environment["GITHUB_OPA_TESTING_HOST"] ?? "localhost"
    static let port = Int(ProcessInfo.processInfo.environment["GITHUB_OPA_TESTING_PORT"] ?? "8181")!
    static let opaListening = try! isPortOpen(host: host, port: port)
    
    @MainActor static var opa: OPA? = nil
    @MainActor static var testStage: TestStage = .data
    @MainActor static let loggingSystem: Void = {
        var factory = LoggingFactory()
        factory.add("Console")
        factory.bootstrap()
    }()
    
    @MainActor
    static func getOPA() throws -> OPA {
        if let opa = opa {
            return opa
        }
        
        _ = loggingSystem
        
        let pool = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        var logger = Logger(label: "OPA-Testing")
        logger.logLevel = .trace
        
        let o = OPA(argument: .init(
            eventLoop: pool.next(),
            host: host,
            port: port,
            logger: logger,
            proxy: try isPortOpen(host: "localhost", port: 9090) ? .server(host: "localhost", port: 9090) : nil
        ))
        
        opa = o
        
        return o
    }
    
    typealias DataType = [String: AnyCodable]
    
    static func prepare(
        datas: [(String, AnyCodable)],
        policies: [(String, String)]
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        for data in datas {
            let res = try await opa.data.save(on: data.0, data: data.1)
            #expect(res.result == true)
        }
        
        for policy in policies {
            try await opa.policy.save(by: policy.0, content: policy.1)
        }
    }
    
    static func clean(
        policies: [(String, String)]
    ) async throws {
        let opa = try await TestingShared.getOPA()
        
        for policy in policies {
            try await opa.policy.delete(of: policy.0)
        }
        
        let datas = try await opa.data.list(as: DataType.self)
        for (k, _) in datas.result {
            try await opa.data.delete(of: "/" + k)
        }
    }
}

func isPortOpen(host: String, port: Int, timeout: TimeAmount = .seconds(3)) throws -> Bool {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
        try? group.syncShutdownGracefully()
    }

    let promise = group.next().makePromise(of: Bool.self)

    let bootstrap = ClientBootstrap(group: group)
        .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

    let futureChannel = bootstrap.connect(host: host, port: port)

    group.next().scheduleTask(in: timeout) {
        promise.fail(ChannelError.connectTimeout(timeout))
    }

    futureChannel.whenSuccess { channel in
        channel.close(mode: .all, promise: nil)
        promise.succeed(true)
    }

    futureChannel.whenFailure { error in
        promise.succeed(false)
    }

    return try promise.futureResult.wait()
}
