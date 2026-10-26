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
