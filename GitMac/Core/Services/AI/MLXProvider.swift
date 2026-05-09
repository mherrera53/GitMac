import Foundation
import MLXLLM
import MLXLMCommon
import MLXLMHuggingFace
import MLXLMTransformers

/// Native Apple Silicon AI provider using MLX framework.
/// Fully on-demand: model loads only when needed, auto-unloads after inactivity.
actor MLXProvider {
    static let shared = MLXProvider()

    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var currentModelName: String?

    private var modelContainer: ModelContainer?
    private var unloadTask: Task<Void, Never>?
    private static let idleTimeout: UInt64 = 3 * 60 * 1_000_000_000 // 3 minutes

    // MARK: - Available Models (small, efficient for on-device)

    struct MLXModel: Identifiable, Equatable, Hashable, Sendable {
        let id: String          // HuggingFace repo ID
        let name: String        // Display name
        let sizeLabel: String   // e.g. "0.5B 4-bit"
    }

    /// Pre-configured models optimized for fast local inference on Apple Silicon
    static let availableModels: [MLXModel] = [
        MLXModel(id: "mlx-community/Qwen3-4B-4bit", name: "Qwen3 4B (Recommended)", sizeLabel: "4B 4-bit ~2.5GB"),
        MLXModel(id: "mlx-community/Qwen3-1.7B-4bit", name: "Qwen3 1.7B", sizeLabel: "1.7B 4-bit ~1.1GB"),
        MLXModel(id: "mlx-community/Qwen3-0.6B-4bit", name: "Qwen3 0.6B (Fastest)", sizeLabel: "0.6B 4-bit ~400MB"),
        MLXModel(id: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit", name: "Qwen 2.5 Coder 7B", sizeLabel: "7B 4-bit ~4.5GB"),
        MLXModel(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", name: "Llama 3.2 3B", sizeLabel: "3B 4-bit ~2GB"),
        MLXModel(id: "mlx-community/gemma-3-1b-it-qat-4bit", name: "Gemma 3 1B", sizeLabel: "1B 4-bit ~700MB"),
        MLXModel(id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit", name: "Qwen 2.5 1.5B", sizeLabel: "1.5B 4-bit ~1GB"),
    ]

    /// Best balance of speed + quality for git operations
    static let defaultModelId = "mlx-community/Qwen3-4B-4bit"

    // MARK: - Model Loading

    /// Load an MLX model by HuggingFace ID.
    /// Downloads the model on first use, then caches it locally.
    func loadModel(_ modelId: String, progressHandler: (@Sendable (Progress) -> Void)? = nil) async throws {
        guard !isLoading else { return }

        // Skip if already loaded with this model
        if isModelLoaded, currentModelName == modelId {
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Unload previous model
        modelContainer = nil
        isModelLoaded = false

        let configuration = ModelConfiguration(id: modelId)

        let container = try await loadModelContainer(
            from: HubClient.default,
            using: TransformersLoader(),
            configuration: configuration
        ) { progress in
            progressHandler?(progress)
        }

        modelContainer = container
        currentModelName = modelId
        isModelLoaded = true
    }

    /// Unload the current model to free GPU/RAM
    func unloadModel() {
        unloadTask?.cancel()
        unloadTask = nil
        modelContainer = nil
        isModelLoaded = false
        currentModelName = nil
    }

    /// Reset the idle timer -- called after every generation
    private func resetIdleTimer() {
        unloadTask?.cancel()
        unloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: MLXProvider.idleTimeout)
            guard !Task.isCancelled else { return }
            await self?.unloadModel()
        }
    }

    /// Ensure model is loaded, loading on-demand if needed
    private func ensureLoaded() async throws {
        if isModelLoaded { return }
        let modelId = UserDefaults.standard.string(forKey: "ai.mlxModel") ?? Self.defaultModelId
        try await loadModel(modelId)
    }

    // MARK: - Text Generation

    /// Generate a complete response -- loads model on-demand, auto-unloads after idle
    func generate(prompt: String, maxTokens: Int = 512, temperature: Float = 0.3) async throws -> String {
        try await ensureLoaded()

        guard let container = modelContainer else {
            throw MLXProviderError.modelNotLoaded
        }

        defer { resetIdleTimer() }

        let output: String = try await container.perform { context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
            let result = try MLXLMCommon.generate(
                input: input,
                parameters: .init(temperature: temperature, topP: 0.9),
                context: context
            ) { tokens in
                tokens.count < maxTokens ? .more : .stop
            }
            return result.output
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Convenience Methods for Git Operations

    /// Generate a commit message from a diff
    func generateCommitMessage(diff: String, style: String = "conventional", maxLength: Int = 72) async throws -> String {
        let prompt = """
        Git commit message for:
        \(diff.prefix(3000))

        Format: \(style) | Max \(maxLength) chars | Imperative mood
        Types: feat/fix/docs/style/refactor/test/chore

        Reply with ONLY the commit message:
        """

        return try await generate(prompt: prompt, maxTokens: 100, temperature: 0.3)
    }

    /// Check if MLX is available on this system (requires Apple Silicon)
    static var isAvailable: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Error Types

    enum MLXProviderError: LocalizedError {
        case modelNotLoaded
        case modelNotFound(String)
        case notAppleSilicon

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "No MLX model loaded. Select a model in Settings to download and load it."
            case .modelNotFound(let id):
                return "MLX model not found: \(id)"
            case .notAppleSilicon:
                return "MLX requires Apple Silicon (M1 or later)"
            }
        }
    }
}
