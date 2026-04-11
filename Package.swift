// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThatMovieNightLife",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TMNLCore",
            targets: ["TMNLCore"]
        ),
        .executable(
            name: "TMNLCoreChecks",
            targets: ["TMNLCoreChecks"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "TMNLCore",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/TMNLCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "TMNLCoreChecks",
            dependencies: ["TMNLCore"],
            path: "Checks/TMNLCoreChecks"
        ),
        .testTarget(
            name: "TMNLCoreTests",
            dependencies: ["TMNLCore"],
            path: "Tests/TMNLCoreTests"
        )
    ]
)
