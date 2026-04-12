// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GitMac", targets: ["GitMac"])
    ],
    dependencies: [
        // Syntax highlighting for code
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0"),
        // Real terminal emulator (VT100/Xterm)
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "GitMac",
            dependencies: [
                "Splash",
                "SwiftTerm"
            ],
            path: "GitMac"
        ),
        .testTarget(
            name: "GitMacTests",
            path: "Tests/GitMacTests"
        )
    ]
)
