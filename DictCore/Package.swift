// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DictCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "DictCore", targets: ["DictCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "DictCore",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/DictCore"
        ),
        .testTarget(
            name: "DictCoreTests",
            dependencies: ["DictCore"],
            path: "Tests/DictCoreTests"
        ),
    ]
)
