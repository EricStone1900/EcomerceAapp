// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.iOS(.v18), .macOS(.v11)],
    products: SharedProduct.allCases.map(\.product),
    targets: SharedProduct.allCases.map(\.target) + SharedProduct.allCases.flatMap(\.testsTargets)
)

enum SharedProduct: String, CaseIterable {

    case Shared

    var path: String { "Sources/Shared" }

    var testsPath: String { "Tests/SharedTests" }

    var testsName: String { "SharedTests" }

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
