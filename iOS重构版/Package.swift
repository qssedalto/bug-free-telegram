// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "是否认同",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS("16.0")],
    products: [
        .library(name: "是否认同", targets: ["是否认同"])
    ],
    targets: [
        .target(
            name: "是否认同",
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
