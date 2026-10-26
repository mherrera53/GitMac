import Foundation

// GPU and prompt-template boundaries only. AIService, its transport policy and
// request lifecycle are compiled unchanged. These tests never load model weights.
actor MLXProvider {
    struct Model {
        let id: String
        let name: String
        let sizeLabel: String
    }
    static let shared = MLXProvider()
    static let availableModels: [Model] = []
    static let defaultModelId = "fixture/no-weights"
    static let isAvailable = true
    func generate(prompt: String, maxTokens: Int, temperature: Float, modelID: String?) throws -> String {
        throw FixtureGPUError.notIncluded
    }
    enum FixtureGPUError: Error { case notIncluded }
}

enum PromptTemplateManager {
    static func getProviderPrompt(for action: String) -> String? { nil }
}
