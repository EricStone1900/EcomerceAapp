// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CameraFilters",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: CameraFiltersProduct.allCases.map(\.product),
    dependencies: [
        .package(path: "../CameraPipeline"),
    ],
    targets: CameraFiltersProduct.allCases.map(\.target) + CameraFiltersProduct.allCases.flatMap(\.testsTargets)
)

enum CameraFiltersProduct: String, CaseIterable {

    case CameraFilters

    var path: String { "Sources/CameraFilters" }

    var testsPath: String { "Tests/CameraFiltersTests" }

    var testsName: String { "CameraFiltersTests" }

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
