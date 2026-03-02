// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MelanSwift",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MelanSwift", targets: ["MelanSwift"]),
    ],
    targets: [
        .target(
            name: "MelanSwift",
            dependencies: ["MelanCoreFFI"],
            path: "Sources/MelanSwift"
        ),
        // After first release, the CI workflow will auto-update this to:
        // .binaryTarget(name: "MelanCoreFFI", url: "https://...", checksum: "...")
        .binaryTarget(
            name: "MelanCoreFFI",
            path: "MelanCoreFFI.xcframework"
        ),
    ]
)
