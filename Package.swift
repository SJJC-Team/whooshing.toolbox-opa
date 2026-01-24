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
        .library( name: "OPA", targets: ["OPA"] ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OPA",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "toolbox-OPA-Tests",
            dependencies: [
                .target(name: "OPA")
            ]
        )
    ]
)
