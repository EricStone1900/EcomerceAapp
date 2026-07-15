// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CameraCore",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: CameraCoreProduct.allCases.map(\.product),
    dependencies: [
        .package(path: "../Shared"),
    ],
    targets: CameraCoreProduct.allCases.map(\.target) + CameraCoreProduct.allCases.flatMap(\.testsTargets)
)

enum CameraCoreProduct: String, CaseIterable {

    case CameraCore

    var path: String { "Sources/CameraCore" }

    var testsPath: String { "Tests/CameraCoreTests" }

    var testsName: String { "CameraCoreTests" }

    var product: Product {
        .library(name: rawValue, targets: [rawValue])
    }

    var target: Target {
        .target(
            name: rawValue,
            dependencies: [
                .product(name: "Shared", package: "Shared"),
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
