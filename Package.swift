// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NotchApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NotchApp",
            targets: ["NotchApp"]
        )
    ],
    dependencies: [
        // Local DynamicNotchKit kullanıyoruz (custom height için)
        // .package(url: "https://github.com/MrKai77/DynamicNotchKit", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "DynamicNotchKit",
            path: "Sources/DynamicNotchKit"
        ),
        .executableTarget(
            name: "NotchApp",
            dependencies: [
                "DynamicNotchKit"
            ],
            path: "Sources",
            exclude: ["DynamicNotchKit"]
        )
    ]
) 