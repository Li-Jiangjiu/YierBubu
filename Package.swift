// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YierBubu",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BubuCore", targets: ["BubuCore"]),
        .executable(name: "BubuDesktop", targets: ["BubuDesktop"])
    ],
    targets: [
        .target(name: "BubuCore"),
        .executableTarget(name: "BubuDesktop", dependencies: ["BubuCore"]),
        .testTarget(name: "BubuCoreTests", dependencies: ["BubuCore"])
    ]
)
