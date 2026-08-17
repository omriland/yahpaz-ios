// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YahpazDomain",
    defaultLocalization: "he",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "YahpazDomain", targets: ["YahpazDomain"]),
    ],
    targets: [
        .target(name: "YahpazDomain"),
        .testTarget(
            name: "YahpazDomainTests",
            dependencies: ["YahpazDomain"]
        ),
    ]
)
