// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ImageLoading",
    platforms: [
        .iOS(.v18),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ImageLoading",
            targets: ["ImageLoading"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.0.0"))
    ],
    targets: [
        .target(
            name: "ImageLoading",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher")
            ]
        ),
        .testTarget(
            name: "ImageLoadingTests",
            dependencies: ["ImageLoading"]
        )
    ]
)
