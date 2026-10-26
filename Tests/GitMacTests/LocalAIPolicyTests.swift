import Foundation
import Testing
@testable import GitMac

private final class AIProtocolState: @unchecked Sendable {
    let lock = NSLock()
    var requests: [URLRequest] = []
    var cloud = false
    var complete = true
    func reset(cloud: Bool = false, complete: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        requests = []; self.cloud = cloud; self.complete = complete
    }
    func snapshot() -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return requests
    }
    func reply(to request: URLRequest) -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        requests.append(request)
        if request.url?.path == "/api/show" {
            if cloud { return ["remote_host": "https://example.invalid", "remote_model": "cloud", "details": ["format": "gguf"]] }
            return ["details": ["format": "gguf"]]
        }
        return ["done": complete, "response": "fix: keep local generation on demand"]
    }
}

private final class AIProtocol: URLProtocol {
    static let state = AIProtocolState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // Foundation may expose upload bytes as httpBodyStream in URLProtocol.
        // Capture the actual bytes rather than treating a nil httpBody as empty.
        var captured = request
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = data
        }
        let payload = Self.state.reply(to: captured)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: payload))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct LocalAIPolicyTests {
    private func service() -> AIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIProtocol.self]
        return AIService(localSession: URLSession(configuration: configuration),
            provider: .ollama, model: "exact-local:3b", localURL: URL(string: "http://127.0.0.1:11434")!)
    }

    @Test func endpointsRejectExternalServersAndCredentialTricks() throws {
        for host in ["http://localhost:11434", "http://127.0.0.1:11434", "http://[::1]:11434"] {
            #expect(try LocalAIRequestPolicy.endpoint(base: host, path: "api/show").path == "/api/show")
        }
        for base in ["https://example.invalid", "http://localhost.example.invalid", "http://localhost@example.invalid",
                     "http://user@localhost", "http://localhost?target=remote", "http://localhost/#redirect", "file:///tmp", "http://localhost/proxy"] {
            #expect(throws: (any Error).self) { try LocalAIRequestPolicy.endpoint(base: base, path: "api/generate") }
        }
    }

    @Test func cloudMetadataFailsClosedRegardlessOfAliasName() {
        #expect(LocalAIRequestPolicy.isLocalWeights(["details": ["format": "gguf"]]))
        #expect(LocalAIRequestPolicy.isLocalWeights(["details": ["format": "safetensors"]]))
        #expect(!LocalAIRequestPolicy.isLocalWeights([:]))
        #expect(!LocalAIRequestPolicy.isLocalWeights(["details": ["format": ""]]))
        #expect(!LocalAIRequestPolicy.isLocalWeights(["remote_model": "hidden", "details": ["format": "gguf"]]))
        #expect(!LocalAIRequestPolicy.isLocalWeights(["remote_host": "https://example.invalid", "details": ["format": "gguf"]]))
    }

    @Test func requestBudgetsAndImmediateUnloadAreExplicit() throws {
        let body = LocalAIRequestPolicy.body(model: "chosen", prompt: "fixture", maxTokens: 50_000, temperature: 0)
        #expect(body["model"] as? String == "chosen")
        #expect(body["keep_alive"] as? Int == 0)
        #expect(body["stream"] as? Bool == false)
        let options = try #require(body["options"] as? [String: Any])
        #expect(options["num_ctx"] as? Int == 4096)
        #expect(options["num_predict"] as? Int == 1024)
        #expect(throws: (any Error).self) { try LocalAIRequestPolicy.validatePrompt(String(repeating: "ñ", count: 6001)) }
        try LocalAIRequestPolicy.validatePrompt(String(repeating: "ñ", count: 6000))
    }

    @Test func cloudPreflightDoesNotReceivePromptOrGenerate() async throws {
        AIProtocol.state.reset(cloud: true)
        do { _ = try await service().generateText(prompt: "SECRET_SYNTHETIC_DIFF"); Issue.record("Cloud alias was accepted") }
        catch { #expect(error.localizedDescription.contains("No prompt was sent")) }
        let requests = AIProtocol.state.snapshot()
        #expect(requests.map { $0.url!.path } == ["/api/show"])
        #expect(requests.allSatisfy { !String(data: $0.httpBody ?? Data(), encoding: .utf8)!.contains("SECRET_SYNTHETIC_DIFF") })
    }

    @Test func realServicePreservesChosenModelAndReleasesLeaseAfterError() async throws {
        let service = service()
        AIProtocol.state.reset(complete: false)
        do { _ = try await service.generateText(prompt: "fixture"); Issue.record("Incomplete generation accepted") }
        catch { #expect(error.localizedDescription.contains("did not complete")) }
        AIProtocol.state.reset()
        let response = try await service.generateText(prompt: "fixture")
        #expect(response == "fix: keep local generation on demand")
        let requests = AIProtocol.state.snapshot()
        #expect(requests.map { $0.url!.path } == ["/api/show", "/api/generate"])
        let request = try #require(requests.last)
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["model"] as? String == "exact-local:3b")
        #expect(body["keep_alive"] as? Int == 0)
    }

    @Test func oversizeAndExternalEndpointsNeverReachTransport() async {
        AIProtocol.state.reset()
        do { _ = try await service().generateText(prompt: String(repeating: "x", count: 12001)); Issue.record("Oversize accepted") }
        catch { #expect(error.localizedDescription.contains("12 KB")) }
        #expect(AIProtocol.state.snapshot().isEmpty)
    }

    @Test func heavyweightLeaseCannotOverlapAcrossServices() async {
        let gate = LocalInferenceGate()
        #expect(await gate.acquire())
        #expect(await !gate.acquire())
        await gate.release()
        #expect(await gate.acquire())
        await gate.release()
    }
}
