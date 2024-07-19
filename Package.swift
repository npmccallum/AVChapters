// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AVChapters",
    platforms: [.macOS(.v12), .iOS(.v13), .macCatalyst(.v13)],
    products: [
        .library(name: "AVChapters", targets: ["AVChapters"]),
    ],
    targets: [
        .target(name: "AVChapters"),
        .testTarget(name: "AVChaptersTests", dependencies: ["AVChapters"]),
    ]
)
