// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpeechKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "SpeechKit",
            targets: ["SpeechKit"]
        ),
    ],
    dependencies: [
        .package(path: "../../Abstraction"),
        .package(url: "https://github.com/soniqo/speech-swift.git", .upToNextMajor(from: "0.0.21")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.8.0")),
    ],
    targets: [
        .target(
            name: "SpeechKit",
            dependencies: [
                .product(name: "SpeechAbstraction", package: "Abstraction"),
                .product(name: "ParakeetASR", package: "speech-swift"),
                .product(name: "KokoroTTS", package: "speech-swift"),
                .product(name: "AudioCommon", package: "speech-swift"),
                .product(name: "RxSwift", package: "RxSwift"),
            ]
        ),
        .testTarget(
            name: "SpeechKitTests",
            dependencies: ["SpeechKit"]
        ),
    ]
)
