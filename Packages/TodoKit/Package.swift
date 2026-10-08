// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TodoKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.0"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.0"),
        // SQLiteData の土台。変更の監視(ValueObservation)を直接使うために明示する。
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.6.0"),
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                "DatabaseClient",
                "DesignSystem",
                "ShieldClient",
                .product(name: "Domain", package: "Domain"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "DatabaseClient",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .target(
            name: "ShieldClient",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "DesignSystem",
            dependencies: [.product(name: "Domain", package: "Domain")]
        ),
        .testTarget(
            name: "DatabaseClientTests",
            dependencies: ["DatabaseClient"]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: ["AppFeature"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
