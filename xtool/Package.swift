// swift-tools-version: 6.0
import Foundation
import PackageDescription

// xtool builds SwiftPM packages, not Xcode projects. This wrapper presents the
// existing `App/` sources (symlinked into Sources/YahpazApp) as the library xtool
// packs into Yahpaz.app. The Xcode project stays the source of truth for
// App Store archives; see docs/xtool-deploy.md.

/// SwiftPM names a path dependency after its folder, so read it instead of hard-coding "yahpaz-ios".
let repoIdentity = URL(fileURLWithPath: Context.packageDirectory)
    .deletingLastPathComponent()
    .lastPathComponent
    .lowercased()

let package = Package(
    name: "YahpazXtool",
    defaultLocalization: "he",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Yahpaz", targets: ["YahpazApp"]),
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.31.0"),
    ],
    targets: [
        .target(
            name: "YahpazApp",
            dependencies: [
                .product(name: "YahpazDomain", package: repoIdentity),
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            exclude: [
                "Info.plist",
                "Yahpaz.entitlements",
                "Yahpaz-Debug.entitlements",
                // Packed at the bundle root through xtool.yml (fonts, map layers, privacy
                // manifest) and as a pre-compiled Assets.car.
                "Resources",
                "Assets.xcassets",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
