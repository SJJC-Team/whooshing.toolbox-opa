import Testing
import NIOCore
import NIOPosix
import NIO
import Foundation
@testable import OPA

struct TestingShared {
    
    enum TestStage {
        case basic
    }
    
    static let host = ProcessInfo.processInfo.environment["GITHUB_OPA_TESTING_HOST"] ?? "localhost"
    static let port = Int(ProcessInfo.processInfo.environment["GITHUB_OPA_TESTING_PORT"] ?? "8181")!
    static let opaListening = try! isPortOpen(host: host, port: port)
    
    @MainActor static var opa: OPA? = nil
    @MainActor static var testStage: TestStage = .basic
    
    @MainActor
    static func getOPA() -> OPA {
        if let opa = opa {
            return opa
        }
        
        let pool = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let o = OPA(argument: .init(
            host: host,
            port: port,
            eventLoop: pool.next(),
            logger: .init(label: "OPA-Testing"))
        )
        
        opa = o
        
        return o
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
