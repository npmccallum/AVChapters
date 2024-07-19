// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AVChapters",
    platforms: [.macOS(.v12), .iOS(.v15), .macCatalyst(.v15)],
    products: [
        .library(name: "AVChapters", targets: ["AVChapters"]),
    ],
    targets: [
        .target(name: "AVChapters"),
        .testTarget(name: "AVChaptersTests", dependencies: ["AVChapters"]),
    ]
)
