// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "charl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "charl", targets: ["CharlApp"]),
    ],
    targets: [
        .target(name: "CharlCore"),
        .target(name: "CharlPlatform", dependencies: ["CharlCore"]),
        .target(name: "CharlMac", dependencies: ["CharlPlatform"]),
        .target(name: "CharlUI", dependencies: ["CharlPlatform"]),
        .executableTarget(name: "CharlApp", dependencies: ["CharlMac", "CharlUI"]),
        // 零依赖测试运行器（CLT 工具链无 XCTest；纯 Swift 断言，Windows 同样可跑）
        .executableTarget(name: "CharlCoreTests", dependencies: ["CharlCore"], path: "Tests/CharlCoreTests"),
        .executableTarget(name: "CharlIntegrationTests", dependencies: ["CharlUI", "CharlMac", "CharlPlatform", "CharlCore"], path: "Tests/CharlIntegrationTests"),
    ]
)