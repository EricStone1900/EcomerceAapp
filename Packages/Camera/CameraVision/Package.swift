// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CameraVision",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: CameraVisionProduct.allCases.map(\.product),
    dependencies: [
        .package(path: "../CameraPipeline"),
    ],
    targets: CameraVisionProduct.allCases.map(\.target) + CameraVisionProduct.allCases.flatMap(\.testsTargets)
)

enum CameraVisionProduct: String, CaseIterable {

    case CameraVision

    var path: String { "Sources/CameraVision" }

    var testsPath: String { "Tests/CameraVisionTests" }

    var testsName: String { "CameraVisionTests" }

    var product: Product {
        .library(name: rawValue, targets: [rawValue])
    }

    var target: Target {
        .target(
            name: rawValue,
            dependencies: [
                .product(name: "CameraPipeline", package: "CameraPipeline"),
            ],
            path: path
        )
    }

    var testsTargets: [Target] {
        [
            .testTarget(
                name: testsName,
                dependencies: [.target(name: rawValue)],
                path: testsPath
            )
        ]
    }
}
