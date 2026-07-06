// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PresentationCore",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        .library(
            name: "PresentationCore",
            targets: ["PresentationCore"]
        ),
    ],
    dependencies: [
        .package(path: "../../Abstraction"),
        .package(path: "../DesignSystem"),
        .package(url: "https://github.com/Swinject/Swinject", .upToNextMajor(from: "2.9.1")),
    ],
    targets: [
        .target(
            name: "PresentationCore",
            dependencies: [
                .product(name: "RoutingAbstraction", package: "Abstraction"),
                .product(name: "AnalyticsAbstraction", package: "Abstraction"),
                .product(name: "DIAbstraction", package: "Abstraction"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Swinject", package: "Swinject"),
            ]
        ),
    ]
)
