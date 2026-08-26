// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StudentAgent",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StudentAgentLib",
            targets: ["StudentAgentLib"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StudentAgentLib",
            dependencies: [],
            path: "StudentAgent",
            exclude: ["Resources/Info.plist"]
        ),
    ]
)
