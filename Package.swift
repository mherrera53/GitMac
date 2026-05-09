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
        // MLX Swift - Native Apple Silicon AI inference
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "3.31.3"),
        // HuggingFace adapters for MLX model downloading and tokenization
        .package(url: "https://github.com/DePasqualeOrg/swift-huggingface-mlx", from: "0.1.0"),
        .package(url: "https://github.com/DePasqualeOrg/swift-transformers-mlx", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "GitMac",
            dependencies: [
                "Splash",
                "SwiftTerm",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLMHuggingFace", package: "swift-huggingface-mlx"),
                .product(name: "MLXLMTransformers", package: "swift-transformers-mlx"),
            ],
            path: "GitMac"
        ),
        .testTarget(
            name: "GitMacTests",
            path: "Tests/GitMacTests"
        )
    ]
)
