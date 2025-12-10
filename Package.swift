f// swift-tools-version: 5.9
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
        // Keychain access for secure credential storage
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        // Syntax highlighting for code
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0"),
    ],
    targets: [
        .executableTarget(
            name: "GitMac",
            dependencies: [
                "KeychainAccess",
                "Splash"
            ],
            path: "GitMac"
        ),
        .testTarget(
            name: "GitMacTests",
            path: "Tests/GitMacTests"
        )
    ]
)
