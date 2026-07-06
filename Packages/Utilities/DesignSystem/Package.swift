// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: DesignSystemProduct.allCases.map(\.product),
    targets: DesignSystemProduct.allCases.map(\.target)
)

enum DesignSystemProduct: String, CaseIterable {

    case DesignSystem

    // MARK: - Properties

    var path: String { "Sources/\(rawValue)" }

    var product: Product {
        .library(
            name: rawValue,
            targets: [rawValue]
        )
    }

    var target: Target {
        .target(
            name: rawValue,
            resources: [.process("Resources")]
        )
    }
}
