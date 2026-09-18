// swift-tools-version: 6.4

import CompilerPluginSupport
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

        .library(name: "Operation Macro", targets: ["Operation Macro"]),
        .library(name: "Operation Macro Core", targets: ["Operation Macro Core"]),
        .library(name: "Operation Foundation Integration", targets: ["Operation Foundation Integration"]),
        .library(name: "Operation Test Support", targets: ["Operation Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.2"..<"604.0.0"),
    ],
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
        .target(
            name: "Operation Macro Core",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .macro(
            name: "Operation Macro Plugin",
            dependencies: [
                "Operation Macro Core",
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Operation Macro",
            dependencies: [
                "Operation Macro Plugin",
                .target(name: "Operation"),
            ]
        ),
        .testTarget(
            name: "Operation Macro Tests",
            dependencies: [
                "Operation Macro",
                "Operation Macro Core",
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
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

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
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
