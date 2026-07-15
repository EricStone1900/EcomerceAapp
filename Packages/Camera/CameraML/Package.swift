// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CameraML",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: CameraMLProduct.allCases.map(\.product),
    dependencies: [
        .package(path: "../CameraPipeline"),
    ],
    targets: CameraMLProduct.allCases.map(\.target) + CameraMLProduct.allCases.flatMap(\.testsTargets)
)

enum CameraMLProduct: String, CaseIterable {

    case CameraML

    var path: String { "Sources/CameraML" }

    var testsPath: String { "Tests/CameraMLTests" }

    var testsName: String { "CameraMLTests" }

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
