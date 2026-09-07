// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-operation",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Operation", targets: ["Operation"]),

        .library(name: "Operation Foundation Integration", targets: ["Operation Foundation Integration"]),
        .library(name: "Operation Test Support", targets: ["Operation Test Support"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Operation",
            dependencies: [
            ],
            path: "Sources/Operation"
        ),
        
        .target(
            name: "Operation Foundation Integration",
            dependencies: [
                .target(name: "Operation"),
            ],
            path: "Sources/Operation Foundation Integration"
        ),
        .target(
            name: "Operation Test Support",
            dependencies: [
                .target(name: "Operation"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Operation Tests",
            dependencies: [
                .target(name: "Operation"),
                .target(name: "Operation Test Support"),
                .target(name: "Operation Foundation Integration"),
            ],
            path: "Tests/Operation Tests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]
}
