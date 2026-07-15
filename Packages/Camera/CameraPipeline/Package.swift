// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CameraPipeline",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: CameraPipelineProduct.allCases.map(\.product),
    targets: CameraPipelineProduct.allCases.map(\.target) + CameraPipelineProduct.allCases.flatMap(\.testsTargets)
)

enum CameraPipelineProduct: String, CaseIterable {

    case CameraPipeline

    var path: String { "Sources/CameraPipeline" }

    var testsPath: String { "Tests/CameraPipelineTests" }

    var testsName: String { "CameraPipelineTests" }

    var product: Product {
        .library(name: rawValue, targets: [rawValue])
    }

    var target: Target {
        .target(name: rawValue, path: path)
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
