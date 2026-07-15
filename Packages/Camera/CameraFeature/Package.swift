// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CameraFeature",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: CameraFeatureProduct.allCases.map(\.product),
    dependencies: [
        .package(path: "../Shared"),
        .package(path: "../CameraCore"),
        .package(path: "../CameraPipeline"),
    ],
    targets: CameraFeatureProduct.allCases.map(\.target) + CameraFeatureProduct.allCases.flatMap(\.testsTargets)
)

enum CameraFeatureProduct: String, CaseIterable {

    case CameraFeature

    var path: String { "Sources/CameraFeature" }

    var testsPath: String { "Tests/CameraFeatureTests" }

    var testsName: String { "CameraFeatureTests" }

    var product: Product {
        .library(name: rawValue, targets: [rawValue])
    }

    var target: Target {
        .target(
            name: rawValue,
            dependencies: [
                .product(name: "Shared", package: "Shared"),
                .product(name: "CameraCore", package: "CameraCore"),
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
