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
        // .binaryTarget(
            name: "MelanCoreFFI",
            url: "https://github.com/gomminjae/Melan-Core/releases/download/v0.1.0-beta/MelanCoreFFI.xcframework.zip",
            checksum: "c3f85cab4aef124bfd583cf1fcbfc3f35409e60936066b1702e3266213af5e19"
        )
        .binaryTarget(
            name: "MelanCoreFFI",
            url: "https://github.com/gomminjae/Melan-Core/releases/download/v0.1.0-beta/MelanCoreFFI.xcframework.zip",
            checksum: "c3f85cab4aef124bfd583cf1fcbfc3f35409e60936066b1702e3266213af5e19"
        ),
    ]
)
