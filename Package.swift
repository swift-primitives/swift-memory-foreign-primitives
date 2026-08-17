// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-memory-foreign-primitives",
    platforms: [
        .macOS("27"),
        .iOS("27"),
        .tvOS("27"),
        .watchOS("27"),
        .visionOS("27"),
    ],
    products: [
        .library(
            name: "Memory Foreign Primitives",
            targets: ["Memory Foreign Primitives"]
        ),
        .library(
            name: "Memory Foreign Primitives Test Support",
            targets: ["Memory Foreign Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Memory Foreign Primitives",
            dependencies: [
                .product(name: "Memory Primitive", package: "swift-memory-primitives"),
                .product(name: "Memory Address Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Region Primitives", package: "swift-memory-primitives"),
                .product(name: "Span Raw Primitives", package: "swift-span-primitives"),
            ]
        ),
        .target(
            name: "Memory Foreign Primitives Test Support",
            dependencies: [
                "Memory Foreign Primitives",
                .product(name: "Memory Primitives Test Support", package: "swift-memory-primitives"),
                .product(name: "Span Primitives Test Support", package: "swift-span-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Memory Foreign Primitives Tests",
            dependencies: [
                "Memory Foreign Primitives",
                "Memory Foreign Primitives Test Support",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
