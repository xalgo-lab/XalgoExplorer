// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "xAlgoExplorer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "xAlgoExplorer", targets: ["xAlgoExplorer"])
    ],
    targets: [
        .executableTarget(
            name: "xAlgoExplorer",
            path: "Sources/xAlgoExplorer",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "xAlgoExplorerTests",
            dependencies: ["xAlgoExplorer"],
            path: "Tests/xAlgoExplorerTests"
        )
    ]
)
