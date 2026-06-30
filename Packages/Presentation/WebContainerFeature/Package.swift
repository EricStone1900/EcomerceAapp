// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WebContainerFeature",
    platforms: [.iOS(.v15)],
    products: WebContainerFeatureProduct.allCases.map(\.product),
    dependencies: [
        .package(url: "https://github.com/Swinject/Swinject", .upToNextMajor(from: "2.9.1")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.8.0")),
        .package(path: "../Abstraction"),
        .package(path: "../Domain"),
        .package(path: "../Utilities/Utils")
    ],
    targets: WebContainerFeatureProduct.allCases.map(\.target) + WebContainerFeatureProduct.allCases.flatMap(\.testsTargets)
)

enum WebContainerFeatureProduct: String, CaseIterable {

    case WebContainerFeature

    // MARK: - Properties

    var path: String { "Sources/\(rawValue)" }

    var testsPath: String { "Tests/\(rawValue)Tests" }

    var testsName: String { "\(rawValue)Tests" }

    var product: Product { Product.Library.library(product: self) }

}

enum ExternalModule: String {

    case Swinject

    case RxSwift

    var dependency: Target.Dependency {

        return switch self {

        case .Swinject:

            .product(
                name: "Swinject",
                package: "Swinject"
            )

        case .RxSwift:

            .product(
                name: "RxSwift",
                package: "RxSwift"
            )
        }
    }
}

enum AbstractionModule: String {

    case WebContainerAbstraction

    case DIAbstraction

    var dependency: Target.Dependency {

        return switch self {

        case .WebContainerAbstraction:

            .product(
                name: "WebContainerAbstraction",
                package: "Abstraction"
            )

        case .DIAbstraction:

            .product(
                name: "DIAbstraction",
                package: "Abstraction"
            )
        }
    }
}

enum DomainModule: String {

    case WebContainerDomain

    var dependency: Target.Dependency {

        return switch self {

        case .WebContainerDomain:

            .product(
                name: "WebContainerDomain",
                package: "Domain"
            )
        }
    }
}

enum Utility: String {

    case Utils

    var dependency: Target.Dependency {

        return switch self {

        case .Utils:

            .product(
                name: "Utils",
                package: "Utils"
            )
        }
    }
}

extension WebContainerFeatureProduct {

    var target: Target {
        .target(
            framework: self,
            dependencies: dependencies,
//            resources: [.copy("Resources")],
            resources: [.process("Resources")],
            swiftSettings: [.unsafeFlags(["-enable-testing"])]
        )
    }

    var testsTargets: [Target] {
        return []
    }

    var dependencies: [Target.Dependency] {
        return switch self {

        case .WebContainerFeature:
            [
                .external(.RxSwift),
                .external(.Swinject),
                .abstraction(.WebContainerAbstraction),
                .abstraction(.DIAbstraction),
                .domain(.WebContainerDomain),
                .utility(.Utils),
            ]
        }

    }

    var testsDependencies: [Target.Dependency] {

        switch self {

        case .WebContainerFeature:
            [
                .internal(.WebContainerFeature)
            ]
        }
    }
}

extension Product.Library {

    static func library(product: WebContainerFeatureProduct) -> Product {
        .library(
            name: product.rawValue,
            type: nil,
            targets: [product.rawValue]
        )
    }
}

extension Target {

    static func target(
        framework: WebContainerFeatureProduct,
        dependencies: [Target.Dependency] = [],
        exclude: [String] = [],
        sources: [String]? = nil,
        resources: [Resource]? = nil,
        publicHeadersPath: String? = nil,
        cSettings: [CSetting]? = nil,
        cxxSettings: [CXXSetting]? = nil,
        swiftSettings: [SwiftSetting]? = nil,
        linkerSettings: [LinkerSetting]? = nil
    ) -> Target {

        .target(
            name: framework.rawValue,
            dependencies: dependencies,
            path: framework.path,
            exclude: exclude,
            sources: sources,
            resources: resources,
            publicHeadersPath: publicHeadersPath,
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings
        )
    }

    static func testTarget(
        framework: WebContainerFeatureProduct,
        dependencies: [Target.Dependency] = [],
        exclude: [String] = [],
        sources: [String]? = nil,
        resources: [Resource]? = nil,
        cSettings: [CSetting]? = nil,
        cxxSettings: [CXXSetting]? = nil,
        swiftSettings: [SwiftSetting]? = nil,
        linkerSettings: [LinkerSetting]? = nil
    ) -> Target {

        .testTarget(
            name: framework.testsName,
            dependencies: dependencies,
            path: framework.testsPath,
            exclude: exclude,
            sources: sources,
            resources: resources,
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings
        )
    }
}

extension Target.Dependency {

    static func `internal`(_ product: WebContainerFeatureProduct) -> Target.Dependency {

        Target.Dependency(stringLiteral: product.rawValue)
    }

    static func external(_ module: ExternalModule) -> Target.Dependency {

        module.dependency

    }

    static func abstraction(_ module: AbstractionModule) -> Target.Dependency {

        module.dependency

    }

    static func domain(_ module: DomainModule) -> Target.Dependency {

        module.dependency

    }

    static func utility(_ module: Utility) -> Target.Dependency {

        module.dependency

    }
}
