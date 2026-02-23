// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoxtralCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "VoxtralCore", targets: ["VoxtralCore"])
    ],
    targets: [
        .target(name: "VoxtralCore")
    ]
)
