// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClipboardMonitor",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "ClipboardMonitor",
            targets: ["ClipboardMonitor"]
        ),
    ],
    targets: [
        .target(
            name: "ClipboardMonitor",
            dependencies: []
        ),
        .testTarget(
            name: "ClipboardMonitorTests",
            dependencies: ["ClipboardMonitor"]
        ),
    ]
)
