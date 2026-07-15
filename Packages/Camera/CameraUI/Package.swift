// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CameraUI",
    platforms: [.iOS(.v18)],
    products: CameraUIProduct.allCases.map(\.product),
    dependencies: [
        .package(path: "../Shared"),
        .package(path: "../CameraCore"),
        .package(path: "../CameraPipeline"),
        .package(path: "../CameraFeature"),
        .package(path: "../../Utilities/DesignSystem"),
    ],
    targets: CameraUIProduct.allCases.map(\.target) + CameraUIProduct.allCases.flatMap(\.testsTargets)
)

enum CameraUIProduct: String, CaseIterable {

    case CameraUI

    var path: String { "Sources/CameraUI" }

    var testsPath: String { "Tests/CameraUITests" }

    var testsName: String { "CameraUITests" }

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
                .product(name: "CameraFeature", package: "CameraFeature"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ],
            path: path
        )
    }

    // 本 stage 无 CameraUI 单测，testsTargets 留空数组，遵循仓库里 WebContainer 类似跳过测试的惯例。
    var testsTargets: [Target] { [] }
}
