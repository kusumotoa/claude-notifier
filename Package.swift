// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "claude-notifier",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "claude-notifier", targets: ["ClaudeNotifier"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeNotifier",
            path: "Sources/ClaudeNotifier"
        )
    ]
)
