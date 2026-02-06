// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "whooshing.toolbox-opa",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library( name: "OPA", targets: ["OPA"] )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.30.3"),
        .package(url: "https://github.com/SJJC-Team/whooshing.toolbox-basic.git", from: "1.5.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "OPA",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "NIOAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "DataConvertable", package: "whooshing.toolbox-basic"),
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "AnyCodable", package: "AnyCodable")
            ]
        ),
        .testTarget(
            name: "toolbox-OPA-Tests",
            dependencies: [
                .target(name: "OPA"),
                .product(name: "AnyCodable", package: "AnyCodable")
            ]
        )
    ]
)
