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

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
