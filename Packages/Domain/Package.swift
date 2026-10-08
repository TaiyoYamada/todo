// swift-tools-version: 6.2

import PackageDescription

// 純粋なロジックと型だけを置くパッケージ。
// Foundation 以外に依存しないので、macOS 上で `swift test` を回せる。
let package = Package(
    name: "Domain",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
    ],
    targets: [
        .target(name: "Domain"),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    ],
    swiftLanguageModes: [.v6]
)
