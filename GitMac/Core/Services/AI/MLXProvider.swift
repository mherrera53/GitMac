import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXLMHuggingFace
import MLXLMTransformers

/// Native Apple Silicon AI provider using MLX framework.
/// On-demand: weights load only for an explicit request and are released after it.
actor MLXProvider {
    static let shared = MLXProvider()

    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var currentModelName: String?

    private var modelContainer: ModelContainer?
    private var isGenerating = false

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
        guard !isLoading else { throw MLXProviderError.busy }

        // Skip if already loaded with this model
        if isModelLoaded, currentModelName == modelId {
            return
        }

        isLoading = true
        defer { isLoading = false }
        Memory.cacheLimit = 16 * 1024 * 1024

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
        modelContainer = nil
        isModelLoaded = false
        currentModelName = nil
        Memory.clearCache()
    }

    /// Ensure model is loaded, loading on-demand if needed
    private func ensureLoaded(modelID: String?) async throws {
        let chosen = modelID ?? UserDefaults.standard.string(forKey: "ai.mlxModel") ?? Self.defaultModelId
        try await loadModel(chosen)
    }

    // MARK: - Text Generation

    /// The helper owns model/context references; they leave scope before cleanup.
    func generate(prompt: String, maxTokens: Int = 512, temperature: Float = 0.3,
                  modelID: String? = nil) async throws -> String {
        guard !isGenerating else { throw MLXProviderError.busy }
        isGenerating = true
        defer { isGenerating = false; unloadModel() }
        try Task.checkCancellation()
        try await ensureLoaded(modelID: modelID)
        try Task.checkCancellation()
        return try await generateLoaded(prompt: prompt, maxTokens: maxTokens, temperature: temperature)
    }

    private func generateLoaded(prompt: String, maxTokens: Int, temperature: Float) async throws -> String {

        guard let container = modelContainer else {
            throw MLXProviderError.modelNotLoaded
        }

        let output: String = try await container.perform { context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
            let stream = try MLXLMCommon.generate(
                input: input,
                parameters: .init(maxTokens: maxTokens, temperature: temperature, topP: 0.9),
                context: context
            )
            var result = ""
            for await generation in stream {
                try Task.checkCancellation()
                if case .chunk(let text) = generation {
                    result += text
                }
            }
            return result
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
        case busy

        var errorDescription: String? {
            switch self {
            case .busy:
                return "Another local model request is running. Wait or cancel it before retrying."
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
