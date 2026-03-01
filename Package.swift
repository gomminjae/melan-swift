// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MelanCore",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MelanCore", targets: ["MelanCore"]),
    ],
    targets: [
        .target(
            name: "MelanCore",
            dependencies: ["MelanCoreFFI"],
            path: "Sources/MelanCore"
        ),
        .binaryTarget(
            name: "MelanCoreFFI",
            path: "MelanCoreFFI.xcframework"
        ),
    ]
)
