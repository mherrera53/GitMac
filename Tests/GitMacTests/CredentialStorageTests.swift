import Foundation
import CryptoKit
import Security
import Testing
@testable import GitMac

private final class FixtureCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var writes = 0
    var readStatus: OSStatus?
    var writeStatus: OSStatus?
    var discardWrites = false
    var afterWrite: (@Sendable () throws -> Void)?

    init(_ values: [String: String]? = nil) throws {
        data = try values.map { try JSONEncoder().encode($0) }
    }
    var writeCount: Int { lock.withLock { writes } }
    func read() throws -> Data? {
        try lock.withLock {
            if let readStatus { throw CredentialStorageError.keychain(readStatus) }
            return data
        }
    }
    func write(_ value: Data) throws {
        try lock.withLock {
            if let writeStatus { throw CredentialStorageError.keychain(writeStatus) }
            writes += 1
            if !discardWrites { data = value }
        }
        try afterWrite?()
    }
}

private struct CredentialFixture {
    let directory: URL
    let legacy: URL
    let key = SymmetricKey(size: .bits256)
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-credentials-\(UUID())")
        legacy = directory.appendingPathComponent(".credentials.enc")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    func writeLegacy(_ values: [String: String]) throws {
        let cleartext = try JSONEncoder().encode(values)
        let sealed = try AES.GCM.seal(cleartext, using: key)
        try #require(sealed.combined).write(to: legacy)
    }
    func manager(_ store: FixtureCredentialStore) -> KeychainManager {
        let key = key
        return KeychainManager(store: store, legacyURL: legacy, legacyKey: { key })
    }
    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}

private func credentialFailure(_ operation: () async throws -> Void) async {
    do { try await operation(); Issue.record("Expected a visible credential storage failure") }
    catch { #expect(error is CredentialStorageError || error is CocoaError) }
}

@Suite("Production credential storage and interrupted migration")
struct CredentialStorageTests {
    @Test func migrationRequiresExplicitActivationAndPreservesSource() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["token": "synthetic"])
        let key = fixture.key
        let store = try FixtureCredentialStore()
        let manager = KeychainManager(store: store, legacyURL: fixture.legacy, legacyKey: { key }, migrationEnabled: false)
        await credentialFailure { _ = try await manager.get(key: "token") }
        #expect(FileManager.default.fileExists(atPath: fixture.legacy.path))
        #expect(store.writeCount == 0)
    }

    @Test func newCredentialsNeverCreateALegacyFile() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let store = try FixtureCredentialStore(), manager = fixture.manager(store)
        try await manager.save(key: "fixture-token", value: "synthetic ñ:token")
        #expect(try await manager.get(key: "fixture-token") == "synthetic ñ:token")
        #expect(!FileManager.default.fileExists(atPath: fixture.legacy.path))
        #expect(store.writeCount == 1)
        try await manager.delete(key: "fixture-token")
        #expect(try await manager.get(key: "fixture-token") == nil)
        let reopened = fixture.manager(store)
        #expect(try await reopened.get(key: "fixture-token") == nil)
    }

    @Test func migratesAllSyntheticKeysAndVerifiesBeforeRetiringFile() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let values = ["github_token": "synthetic-github", "openai_api_key": "synthetic-ai", "unknown_future_key": "保留"]
        try fixture.writeLegacy(values)
        let store = try FixtureCredentialStore(), manager = fixture.manager(store)
        for (key, value) in values { #expect(try await manager.get(key: key) == value) }
        #expect(!FileManager.default.fileExists(atPath: fixture.legacy.path))
        #expect(store.writeCount == 1)
    }

    @Test func failedWritePreservesOnlyLegacyCopy() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["token": "synthetic-original"])
        let original = try Data(contentsOf: fixture.legacy)
        let store = try FixtureCredentialStore()
        store.writeStatus = errSecAuthFailed
        await credentialFailure { _ = try await fixture.manager(store).get(key: "token") }
        #expect(try Data(contentsOf: fixture.legacy) == original)
        #expect(try store.read() == nil)
    }

    @Test func failedReadbackDoesNotDeleteLegacyData() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["token": "synthetic-original"])
        let store = try FixtureCredentialStore()
        store.discardWrites = true
        await credentialFailure { _ = try await fixture.manager(store).get(key: "token") }
        #expect(FileManager.default.fileExists(atPath: fixture.legacy.path))
    }

    @Test func interruptionAfterPersistCanBeRetriedWithoutLosingNewerValues() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["token": "old", "legacy-only": "keep"])
        let store = try FixtureCredentialStore(["token": "newer", "keychain-only": "keep-too"])
        let key = fixture.key
        let interrupted = KeychainManager(store: store, legacyURL: fixture.legacy, legacyKey: { key },
            removeLegacy: { _ in throw CocoaError(.fileWriteUnknown) })
        await credentialFailure { _ = try await interrupted.get(key: "token") }
        #expect(FileManager.default.fileExists(atPath: fixture.legacy.path))
        let resumed = fixture.manager(store)
        #expect(try await resumed.get(key: "token") == "newer")
        #expect(try await resumed.get(key: "legacy-only") == "keep")
        #expect(try await resumed.get(key: "keychain-only") == "keep-too")
        #expect(!FileManager.default.fileExists(atPath: fixture.legacy.path))
    }

    @Test(arguments: [errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable])
    func lockedDeniedOrUnavailableNeverLooksLikeMissingCredentials(_ status: OSStatus) async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let store = try FixtureCredentialStore(["token": "synthetic"])
        store.readStatus = status
        let manager = fixture.manager(store)
        await credentialFailure { _ = try await manager.get(key: "token") }
        await credentialFailure { try await manager.save(key: "token", value: "replacement") }
        await credentialFailure { try await manager.delete(key: "token") }
        #expect(store.writeCount == 0)
    }

    @Test func corruptLegacyIsNotSilentlyReset() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let corrupt = Data("not an encrypted credential store".utf8)
        try corrupt.write(to: fixture.legacy)
        let store = try FixtureCredentialStore()
        await credentialFailure { try await fixture.manager(store).save(key: "token", value: "replacement") }
        #expect(try Data(contentsOf: fixture.legacy) == corrupt)
        #expect(store.writeCount == 0)
    }

    @Test func unreadableLegacyPropagatesErrorAndPreservesOriginal() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["token": "synthetic"])
        let original = try Data(contentsOf: fixture.legacy)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fixture.legacy.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fixture.legacy.path) }
        let store = try FixtureCredentialStore()
        await credentialFailure { _ = try await fixture.manager(store).get(key: "token") }
        #expect(store.writeCount == 0)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fixture.legacy.path)
        #expect(try Data(contentsOf: fixture.legacy) == original)
    }

    @Test func oversizedLegacyIsRejectedBeforeWritingKeychain() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try Data(repeating: 0, count: 1024 * 1024 + 1).write(to: fixture.legacy)
        let store = try FixtureCredentialStore()
        await credentialFailure { _ = try await fixture.manager(store).get(key: "token") }
        #expect(store.writeCount == 0)
        #expect(FileManager.default.fileExists(atPath: fixture.legacy.path))
    }

    @Test func failedUpdateAndDeleteDoNotChangePersistedValuesOrCacheSuccess() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let store = try FixtureCredentialStore(["token": "synthetic-original"])
        store.writeStatus = errSecNotAvailable
        let manager = fixture.manager(store)
        await credentialFailure { try await manager.save(key: "token", value: "synthetic-replacement") }
        #expect(try await manager.get(key: "token") == "synthetic-original")
        await credentialFailure { try await manager.delete(key: "token") }
        #expect(try await manager.get(key: "token") == "synthetic-original")
        #expect(store.writeCount == 0)
    }

    @Test func corruptKeychainDataIsNotOverwritten() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let store = try FixtureCredentialStore()
        try store.write(Data("corrupt".utf8))
        await credentialFailure { try await fixture.manager(store).save(key: "token", value: "replacement") }
        #expect(try store.read() == Data("corrupt".utf8))
        #expect(store.writeCount == 1)
    }

    @Test func missingMachineIdentityPreservesLegacyFile() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["token": "synthetic"])
        let store = try FixtureCredentialStore()
        let manager = KeychainManager(store: store, legacyURL: fixture.legacy,
            legacyKey: { throw CredentialStorageError.legacyKeyUnavailable })
        await credentialFailure { _ = try await manager.get(key: "token") }
        #expect(FileManager.default.fileExists(atPath: fixture.legacy.path))
        #expect(store.writeCount == 0)
    }

    @Test func symlinkLegacyIsRejectedWithoutReadingItsTarget() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let target = fixture.directory.appendingPathComponent("synthetic-target")
        try Data("untouched".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: fixture.legacy, withDestinationURL: target)
        let store = try FixtureCredentialStore()
        await credentialFailure { _ = try await fixture.manager(store).get(key: "token") }
        #expect(try Data(contentsOf: target) == Data("untouched".utf8))
        #expect(store.writeCount == 0)
    }

    @Test func changedLegacyDuringMigrationIsPreserved() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["token": "synthetic"])
        let url = fixture.legacy
        let store = try FixtureCredentialStore()
        store.afterWrite = { try Data("changed by fixture".utf8).write(to: url) }
        await credentialFailure { _ = try await fixture.manager(store).get(key: "token") }
        #expect(try Data(contentsOf: url) == Data("changed by fixture".utf8))
    }

    @Test func realSecurityAdapterRoundTripsOnlyUniqueSyntheticService() throws {
        let service = "com.gitmac.tests.credentials.\(UUID())"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "credential-store.v1"]
        defer { SecItemDelete(query as CFDictionary) }
        let store = SecurityCredentialStore(service: service)
        #expect(try store.read() == nil)
        let original = Data("synthetic-only".utf8)
        try store.write(original)
        #expect(try store.read() == original)
        let replacement = Data("synthetic-replacement".utf8)
        try store.write(replacement)
        #expect(try store.read() == replacement)
        #expect(SecItemDelete(query as CFDictionary) == errSecSuccess)
        #expect(try store.read() == nil)
    }
}

@Suite("GitHub sign-in regression checks", .serialized)
struct GitHubAuthenticationTests {
    @Test func newCredentialsRemainReadableWithUnapprovedLegacyAndSurviveReopen() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["github_token": "old-synthetic", "legacy-only": "keep"])
        let original = try Data(contentsOf: fixture.legacy)
        let store = try FixtureCredentialStore()
        let manager = KeychainManager(store: store, legacyURL: fixture.legacy,
            legacyKey: { throw CredentialStorageError.legacyKeyUnavailable }, migrationEnabled: false)
        try await manager.save(key: "github_oauth_client_id", value: "synthetic-client")
        try await manager.saveGitHubToken("new-synthetic", username: "fixture")
        try await manager.saveLinearToken("synthetic-linear")
        #expect(store.writeCount == 3)
        let reopened = KeychainManager(store: store, legacyURL: fixture.legacy,
            legacyKey: { throw CredentialStorageError.legacyKeyUnavailable }, migrationEnabled: false)
        #expect(try await reopened.get(key: "github_oauth_client_id") == "synthetic-client")
        #expect(try await reopened.getGitHubToken() == "new-synthetic")
        #expect(try await reopened.getGitHubUsername() == "fixture")
        #expect(try await reopened.getLinearToken() == "synthetic-linear")
        #expect(try Data(contentsOf: fixture.legacy) == original)
    }

    @Test func disconnectDoesNotResurrectLegacyTokenDuringLaterMigration() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        try fixture.writeLegacy(["github_token": "old-synthetic", "github_username": "old-user", "other": "keep"])
        let key = fixture.key, store = try FixtureCredentialStore()
        let manager = KeychainManager(store: store, legacyURL: fixture.legacy, legacyKey: { key }, migrationEnabled: false)
        try await manager.deleteGitHubCredentials()
        #expect(store.writeCount == 1)
        #expect(try await manager.getGitHubToken() == nil)
        let migrated = fixture.manager(store)
        #expect(try await migrated.getGitHubToken() == nil)
        #expect(try await migrated.getGitHubUsername() == nil)
        #expect(try await migrated.get(key: "other") == "keep")
    }

    @Test func failedClientIDSaveIsVisibleAndDoesNotCacheSuccessOrRemoveLegacyDefaults() async throws {
        let fixture = try CredentialFixture(); defer { fixture.cleanup() }
        let name = "GitMac.OAuth.fixture.\(UUID())", defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("synthetic-legacy-id", forKey: "GitHubOAuthClientId")
        let store = try FixtureCredentialStore(), manager = fixture.manager(store)
        store.writeStatus = errSecNotAvailable
        let oauth = GitHubOAuth(keychain: manager, defaults: defaults)
        await credentialFailure { try await oauth.setClientId("synthetic-new-id") }
        #expect(defaults.string(forKey: "GitHubOAuthClientId") == "synthetic-legacy-id")
        await credentialFailure { _ = try await oauth.getClientId() }
        store.writeStatus = nil
        try await oauth.setClientId("  synthetic-new-id  ")
        #expect(defaults.string(forKey: "GitHubOAuthClientId") == nil)
        let reopened = GitHubOAuth(keychain: fixture.manager(store), defaults: defaults)
        #expect(try await reopened.getClientId() == "synthetic-new-id")
    }

    @Test func deviceFlowEncodesFieldsAndRespectsSlowDown() async throws {
        let fixture = try OAuthNetworkFixture(); defer { fixture.cleanup() }
        try await fixture.oauth.setClientId("client&scope=wrong+value")
        fixture.transport.responses = [OAuthNetworkFixture.device(),
            (200, "{\"error\":\"authorization_pending\"}"),
            (200, "{\"error\":\"slow_down\",\"interval\":12}"),
            (200, "access_token=synthetic%2Btoken&token_type=bearer&scope=read%3Auser")]
        let code = try await fixture.oauth.startAuthentication()
        #expect(try await fixture.oauth.waitForAuthentication(deviceCode: code) == "synthetic+token")
        #expect(fixture.clock.delays == [5, 5, 12])
        #expect(fixture.transport.requests.count == 4)
        let body = try #require(fixture.transport.requests.first?.httpBody)
        #expect(String(decoding: body, as: UTF8.self).contains("client_id=client%26scope%3Dwrong%2Bvalue"))
        #expect(fixture.transport.requests.allSatisfy { $0.url?.host == "github.com" })
    }

    @Test(arguments: ["device_flow_disabled", "incorrect_client_credentials", "access_denied"])
    func actionableGitHubErrors(_ code: String) async throws {
        let fixture = try OAuthNetworkFixture(); defer { fixture.cleanup() }
        try await fixture.oauth.setClientId("synthetic-client")
        fixture.transport.responses = [(400, "{\"error\":\"\(code)\"}")]
        do { _ = try await fixture.oauth.startAuthentication(); Issue.record("Expected GitHub error") }
        catch let error as GitHubOAuth.OAuthError {
            if code == "device_flow_disabled" { #expect(error.localizedDescription.contains("Enable Device Flow")) }
            else { #expect(!error.localizedDescription.contains("Invalid response")) }
        }
        #expect(fixture.transport.requests.count == 1)
    }

    @Test func expiredAndCancelledCodesNeverProduceTokens() async throws {
        let fixture = try OAuthNetworkFixture(); defer { fixture.cleanup() }
        try await fixture.oauth.setClientId("synthetic-client")
        fixture.transport.responses = [OAuthNetworkFixture.device(expires: 5)]
        let code = try await fixture.oauth.startAuthentication()
        do { _ = try await fixture.oauth.waitForAuthentication(deviceCode: code); Issue.record("Expected expiry") }
        catch let error as GitHubOAuth.OAuthError { #expect(error.localizedDescription.contains("expired")) }
        await fixture.oauth.cancelAuthentication()
        do { _ = try await fixture.oauth.waitForAuthentication(deviceCode: code); Issue.record("Expected cancellation") }
        catch let error as GitHubOAuth.OAuthError { #expect(error.localizedDescription.contains("cancelled")) }
        #expect(fixture.transport.requests.count == 1)
    }

    @Test(arguments: [true, false])
    func cancellationStopsAnActivePollingWait(cancelParent: Bool) async throws {
        let fixture = try OAuthNetworkFixture(); defer { fixture.cleanup() }
        let (entered, signal) = AsyncStream<Void>.makeStream()
        let oauth = GitHubOAuth(keychain: fixture.manager, defaults: fixture.defaults, session: fixture.session,
            pause: { _ in
                signal.yield(())
                try await Task.sleep(nanoseconds: 60_000_000_000)
            })
        try await oauth.setClientId("synthetic-client")
        fixture.transport.responses = [OAuthNetworkFixture.device()]
        let code = try await oauth.startAuthentication()
        let task = Task { try await oauth.waitForAuthentication(deviceCode: code) }
        for await _ in entered { break }
        if cancelParent { task.cancel() }
        else { await oauth.cancelAuthentication() }
        do { _ = try await task.value; Issue.record("Cancellation must end the polling task") }
        catch is CancellationError { }
        #expect(fixture.transport.requests.count == 1)
        signal.finish()
    }

    @Test func malformedResponseCannotOpenAnotherHostOrTrapOnNegativeInterval() async throws {
        let fixture = try OAuthNetworkFixture(); defer { fixture.cleanup() }
        try await fixture.oauth.setClientId("synthetic-client")
        for response in [OAuthNetworkFixture.device(interval: -1),
                         (200, OAuthNetworkFixture.device().1.replacingOccurrences(of: "github.com", with: "example.invalid"))] {
            fixture.transport.responses = [response]
            do { _ = try await fixture.oauth.startAuthentication(); Issue.record("Expected invalid response") }
            catch is GitHubOAuth.OAuthError { }
        }
    }

    @Test func accountValidationDoesNotOverwriteWorkingCredentialsOn401() async throws {
        let fixture = try OAuthNetworkFixture(); defer { fixture.cleanup() }
        try await fixture.manager.saveGitHubToken("synthetic-original", username: "original")
        let service = GitHubService(keychainManager: fixture.manager, session: fixture.session)
        fixture.transport.responses = [(401, "{}")]
        do { _ = try await service.authenticate(token: "synthetic-invalid"); Issue.record("Expected rejection") }
        catch is GitHubError { }
        #expect(try await fixture.manager.getGitHubToken() == "synthetic-original")
        #expect(try await fixture.manager.getGitHubUsername() == "original")
        fixture.transport.responses = [(200, "{\"id\":1,\"login\":\"new-user\",\"avatar_url\":\"https://example.invalid/avatar\",\"html_url\":\"https://github.com/new-user\"}")]
        let before = fixture.store.writeCount
        let user = try await service.authenticate(token: "synthetic-verified")
        #expect(user.login == "new-user")
        #expect(fixture.store.writeCount == before + 1)
        #expect(try await fixture.manager.getGitHubToken() == "synthetic-verified")
        #expect(try await fixture.manager.getGitHubUsername() == "new-user")
        #expect(fixture.transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "If-None-Match") == nil })
    }
}

private final class OAuthFixtureClock: @unchecked Sendable {
    private let lock = NSLock()
    private var elapsed: TimeInterval = 100
    private var recorded: [TimeInterval] = []
    var now: TimeInterval { lock.withLock { elapsed } }
    var delays: [TimeInterval] { lock.withLock { recorded } }
    func advance(_ delay: TimeInterval) { lock.withLock { elapsed += delay; recorded.append(delay) } }
}

private final class OAuthFixtureTransport: @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [(Int, String)] = []
    private var captured: [URLRequest] = []
    var responses: [(Int, String)] {
        get { lock.withLock { queue } }
        set { lock.withLock { queue = newValue } }
    }
    var requests: [URLRequest] { lock.withLock { captured } }
    func respond(_ request: URLRequest) throws -> (Int, Data) {
        try lock.withLock {
            var capturedRequest = request
            if capturedRequest.httpBody == nil, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
                while true {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
                    if count == 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
                capturedRequest.httpBody = data
            }
            captured.append(capturedRequest)
            guard !queue.isEmpty else { throw URLError(.badServerResponse) }
            let response = queue.removeFirst()
            return (response.0, Data(response.1.utf8))
        }
    }
}

private final class OAuthFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var transport: OAuthFixtureTransport?
    static func install(_ value: OAuthFixtureTransport?) { lock.withLock { transport = value } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let transport = try Self.lock.withLock { try #require(Self.transport) }
            let (status, data) = try transport.respond(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private struct OAuthNetworkFixture {
    let credentials: CredentialFixture
    let store: FixtureCredentialStore
    let manager: KeychainManager
    let session: URLSession
    let oauth: GitHubOAuth
    let defaults: UserDefaults
    let defaultsName: String
    let clock = OAuthFixtureClock()
    let transport = OAuthFixtureTransport()
    init() throws {
        credentials = try CredentialFixture()
        store = try FixtureCredentialStore()
        manager = credentials.manager(store)
        defaultsName = "GitMac.OAuth.network.\(UUID())"
        defaults = try #require(UserDefaults(suiteName: defaultsName))
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OAuthFixtureURLProtocol.self]
        session = URLSession(configuration: config)
        OAuthFixtureURLProtocol.install(transport)
        let clock = clock
        oauth = GitHubOAuth(keychain: manager, defaults: defaults, session: session,
                            uptime: { clock.now }, pause: { clock.advance($0); try Task.checkCancellation() })
    }
    static func device(expires: Int = 900, interval: Int = 5) -> (Int, String) {
        (200, "{\"device_code\":\"synthetic-device\",\"user_code\":\"TEST-CODE\",\"verification_uri\":\"https://github.com/login/device\",\"expires_in\":\(expires),\"interval\":\(interval)}")
    }
    func cleanup() {
        session.invalidateAndCancel()
        OAuthFixtureURLProtocol.install(nil)
        defaults.removePersistentDomain(forName: defaultsName)
        credentials.cleanup()
    }
}
