// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PingBar",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "PingBarCore",
            path: "Sources/PingBarCore"
        ),
        .executableTarget(
            name: "PingBar",
            dependencies: ["PingBarCore"],
            path: "Sources/PingBar"
        ),
        .testTarget(
            name: "PingBarTests",
            dependencies: ["PingBarCore"],
            path: "Tests/PingBarTests"
        ),
    ]
)
