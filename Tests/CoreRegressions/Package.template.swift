// swift-tools-version: 6.0
import PackageDescription

// Materialized in a disposable directory by test-production-suites.mjs.
// Sources are links to actual first-party production files, not model copies.
let package = Package(
    name: "GitMacProductionTests",
    platforms: [.macOS(.v14)],
    products: [.library(name: "GitMac", targets: ["GitMac"])],
    targets: [
        .target(name: "GitMac", path: "Sources"),
        .testTarget(name: "GitMacTests", dependencies: ["GitMac"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
