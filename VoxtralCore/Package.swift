// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoxtralCore",
    platforms: [
        .iOS(.v26),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VoxtralCore", targets: ["VoxtralCore"])
    ],
    targets: [
        .target(name: "VoxtralCore"),
        .testTarget(name: "VoxtralCoreTests", dependencies: ["VoxtralCore"])
    ]
)
