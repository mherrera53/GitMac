//
//  CloudSyncService.swift
//  GitMac
//
//  iCloud/CloudKit sync for settings, themes, workflows, and bookmarks
//

import SwiftUI
import CloudKit
import Combine

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case error(String)
    case offline
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .syncing: return "Syncing..."
        case .success: return "Synced"
        case .error: return "Error"
        case .offline: return "Offline"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "icloud"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .success: return "icloud.fill"
        case .error: return "icloud.slash"
        case .offline: return "wifi.slash"
        }
    }
    
    @MainActor var color: Color {
        switch self {
        case .idle: return AppTheme.textSecondary
        case .syncing: return AppTheme.accent
        case .success: return AppTheme.success
        case .error: return AppTheme.error
        case .offline: return AppTheme.warning
        }
    }
}

// MARK: - Sync Item Types

enum SyncItemType: String, CaseIterable {
    case themes = "themes"
    case settings = "settings"
    case workflows = "workflows"
    case repositoryBookmarks = "repositoryBookmarks"
    case promptTemplates = "promptTemplates"
    
    var displayName: String {
        switch self {
        case .themes: return "Themes"
        case .settings: return "Settings"
        case .workflows: return "Workflows"
        case .repositoryBookmarks: return "Repository Bookmarks"
        case .promptTemplates: return "AI Prompt Templates"
        }
    }
    
    var recordType: String {
        return "GitMac_\(rawValue)"
    }
}

// MARK: - Sync Conflict

struct SyncConflict: Identifiable {
    let id = UUID()
    let itemType: SyncItemType
    let localModified: Date
    let remoteModified: Date
    let localData: Data
    let remoteData: Data
    
    enum Resolution {
        case keepLocal
        case keepRemote
        case merge
    }
}

// MARK: - Cloud Sync Service

@MainActor
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()
    
    // MARK: - Published Properties
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isSyncEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: "cloudSyncEnabled")
            if isSyncEnabled {
                Task { await checkAccountStatus() }
            }
        }
    }
    @Published var syncItems: Set<SyncItemType> = [.themes, .settings, .workflows, .promptTemplates]
    @Published var conflicts: [SyncConflict] = []
    
    // MARK: - Private Properties
    
    private let container: CKContainer
    private let database: CKDatabase
    private var subscriptions: Set<AnyCancellable> = []
    private let syncQueue = DispatchQueue(label: "com.gitmac.cloudsync", qos: .utility)
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.gitmac.app")
        database = container.privateCloudDatabase
        
        // Load saved preferences
        isSyncEnabled = UserDefaults.standard.bool(forKey: "cloudSyncEnabled")
        lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudSyncDate") as? Date
        
        // Setup observers
        setupObservers()
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            
            switch status {
            case .available:
                syncStatus = .idle
            case .noAccount:
                syncStatus = .error("No iCloud account")
            case .restricted:
                syncStatus = .error("iCloud restricted")
            case .couldNotDetermine:
                syncStatus = .offline
            case .temporarilyUnavailable:
                syncStatus = .offline
            @unknown default:
                syncStatus = .offline
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Sync Operations
    
    /// Sync all enabled item types
    func syncAll() async throws {
        guard isSyncEnabled else { return }
        
        syncStatus = .syncing
        
        do {
            for itemType in syncItems {
                try await sync(itemType: itemType)
            }
            
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastCloudSyncDate")
            syncStatus = .success
            
            // Reset to idle after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.syncStatus == .success {
                    self?.syncStatus = .idle
                }
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Sync a specific item type
    func sync(itemType: SyncItemType) async throws {
        // Fetch remote data
        let remoteRecord = try await fetchRemoteRecord(for: itemType)
        
        // Get local data
        let localData = getLocalData(for: itemType)
        let localModified = getLocalModifiedDate(for: itemType)
        
        if let remote = remoteRecord {
            // Compare and resolve
            let remoteModified = remote.modificationDate ?? Date.distantPast
            let remoteData = remote["data"] as? Data
            
            if let remoteData = remoteData {
                if remoteModified > localModified {
                    // Remote is newer - update local
                    try applyRemoteData(remoteData, for: itemType)
                } else if localModified > remoteModified {
                    // Local is newer - update remote
                    try await uploadLocalData(localData, for: itemType, existingRecord: remote)
                } else {
                    // Same - no action needed
                }
            }
        } else {
            // No remote record - create one
            if let localData = localData {
                try await uploadLocalData(localData, for: itemType, existingRecord: nil)
            }
        }
    }
    
    /// Sync themes specifically
    func syncThemes() async throws {
        try await sync(itemType: .themes)
    }
    
    /// Sync settings specifically
    func syncSettings() async throws {
        try await sync(itemType: .settings)
    }
    
    /// Sync workflows specifically
    func syncWorkflows() async throws {
        try await sync(itemType: .workflows)
    }
    
    /// Sync prompt templates specifically
    func syncPromptTemplates() async throws {
        try await sync(itemType: .promptTemplates)
    }
    
    // MARK: - Local Data Operations
    
    private func getLocalData(for itemType: SyncItemType) -> Data? {
        switch itemType {
        case .themes:
            return UserDefaults.standard.data(forKey: "customThemes")
        case .settings:
            return encodeAppSettings()
        case .workflows:
            return UserDefaults.standard.data(forKey: "userWorkflows")
        case .repositoryBookmarks:
            return UserDefaults.standard.data(forKey: "repositoryBookmarks")
        case .promptTemplates:
            return UserDefaults.standard.data(forKey: "com.gitmac.promptTemplates")
        }
    }
    
    private func getLocalModifiedDate(for itemType: SyncItemType) -> Date {
        let key = "lastModified_\(itemType.rawValue)"
        return UserDefaults.standard.object(forKey: key) as? Date ?? Date.distantPast
    }
    
    private func setLocalModifiedDate(_ date: Date, for itemType: SyncItemType) {
        let key = "lastModified_\(itemType.rawValue)"
        UserDefaults.standard.set(date, forKey: key)
    }
    
    private func applyRemoteData(_ data: Data, for itemType: SyncItemType) throws {
        switch itemType {
        case .themes:
            UserDefaults.standard.set(data, forKey: "customThemes")
            // Notify theme manager to reload
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
            
        case .settings:
            try decodeAndApplySettings(data)
            
        case .workflows:
            UserDefaults.standard.set(data, forKey: "userWorkflows")
            
        case .repositoryBookmarks:
            UserDefaults.standard.set(data, forKey: "repositoryBookmarks")
            
        case .promptTemplates:
            UserDefaults.standard.set(data, forKey: "com.gitmac.promptTemplates")
            // Notify prompt template manager to reload
            NotificationCenter.default.post(name: NSNotification.Name("PromptTemplatesDidChange"), object: nil)
        }
        
        setLocalModifiedDate(Date(), for: itemType)
    }
    
    // MARK: - CloudKit Operations
    
    private func fetchRemoteRecord(for itemType: SyncItemType) async throws -> CKRecord? {
        let recordID = CKRecord.ID(recordName: itemType.recordType)
        
        do {
            let record = try await database.record(for: recordID)
            return record
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }
    
    private func uploadLocalData(_ data: Data?, for itemType: SyncItemType, existingRecord: CKRecord?) async throws {
        guard let data = data else { return }
        
        let record: CKRecord
        if let existing = existingRecord {
            record = existing
        } else {
            let recordID = CKRecord.ID(recordName: itemType.recordType)
            record = CKRecord(recordType: itemType.recordType, recordID: recordID)
        }
        
        record["data"] = data as CKRecordValue
        record["modifiedAt"] = Date() as CKRecordValue
        
        try await database.save(record)
        setLocalModifiedDate(Date(), for: itemType)
    }
    
    // MARK: - Settings Encoding/Decoding
    
    private func encodeAppSettings() -> Data? {
        var settings: [String: Any] = [:]
        
        // Collect AppStorage values
        settings["diffViewMode"] = UserDefaults.standard.string(forKey: "diffViewMode")
        settings["showLineNumbers"] = UserDefaults.standard.bool(forKey: "diffShowLineNumbers")
        settings["showMinimap"] = UserDefaults.standard.bool(forKey: "diffShowMinimap")
        settings["wordWrap"] = UserDefaults.standard.bool(forKey: "diffWordWrap")
        
        // Add more settings as needed
        
        return try? JSONSerialization.data(withJSONObject: settings)
    }
    
    private func decodeAndApplySettings(_ data: Data) throws {
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if let mode = settings["diffViewMode"] as? String {
            UserDefaults.standard.set(mode, forKey: "diffViewMode")
        }
        if let showNumbers = settings["showLineNumbers"] as? Bool {
            UserDefaults.standard.set(showNumbers, forKey: "diffShowLineNumbers")
        }
        if let showMinimap = settings["showMinimap"] as? Bool {
            UserDefaults.standard.set(showMinimap, forKey: "diffShowMinimap")
        }
        if let wordWrap = settings["wordWrap"] as? Bool {
            UserDefaults.standard.set(wordWrap, forKey: "diffWordWrap")
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Listen for changes that should trigger sync
        NotificationCenter.default.publisher(for: .themeDidChange)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    try? await self?.syncThemes()
                }
            }
            .store(in: &subscriptions)
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(_ conflict: SyncConflict, resolution: SyncConflict.Resolution) async throws {
        switch resolution {
        case .keepLocal:
            try await uploadLocalData(conflict.localData, for: conflict.itemType, existingRecord: nil)
        case .keepRemote:
            try applyRemoteData(conflict.remoteData, for: conflict.itemType)
        case .merge:
            // For now, merge means keep local (could be smarter later)
            try await uploadLocalData(conflict.localData, for: conflict.itemType, existingRecord: nil)
        }
        
        // Remove resolved conflict
        conflicts.removeAll { $0.id == conflict.id }
    }
}

// MARK: - Cloud Sync Settings View

struct CloudSyncSettingsView: View {
    @StateObject private var syncService = CloudSyncService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: syncService.syncStatus.icon)
                    .font(.title2)
                    .foregroundColor(syncService.syncStatus.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(syncService.syncStatus.displayName)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $syncService.isSyncEnabled)
                    .toggleStyle(.switch)
            }
            
            if syncService.isSyncEnabled {
                Divider()
                
                // Last sync
                if let lastSync = syncService.lastSyncDate {
                    HStack {
                        Text("Last synced:")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Button("Sync Now") {
                            Task {
                                try? await syncService.syncAll()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(syncService.syncStatus == .syncing)
                    }
                }
                
                Divider()
                
                // Sync items
                Text("Sync Items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.textPrimary)
                
                ForEach(SyncItemType.allCases, id: \.self) { itemType in
                    Toggle(itemType.displayName, isOn: Binding(
                        get: { syncService.syncItems.contains(itemType) },
                        set: { enabled in
                            if enabled {
                                syncService.syncItems.insert(itemType)
                            } else {
                                syncService.syncItems.remove(itemType)
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
    }
}

// MARK: - Preview

#Preview("Cloud Sync Settings") {
    CloudSyncSettingsView()
        .frame(width: 400)
        .padding()
        .background(AppTheme.background)
}
