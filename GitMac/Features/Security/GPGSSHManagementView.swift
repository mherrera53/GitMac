import SwiftUI

// MARK: - GPG/SSH Management View

struct GPGSSHManagementView: View {
    @StateObject private var viewModel = GPGSSHViewModel()
    @State private var selectedTab: SecurityTab = .ssh
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SecurityTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: tab.icon)
                                .foregroundColor(AppTheme.textSecondary)
                            Text(tab.title)
                        }
                        .font(DesignTokens.Typography.callout)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(selectedTab == tab ? AppTheme.info : Color.clear)
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .background(AppTheme.textMuted.opacity(0.1))
            
            // Content
            ScrollView {
                switch selectedTab {
                case .ssh:
                    sshSection
                case .gpg:
                    gpgSection
                }
            }
        }
        .task {
            await viewModel.loadKeys()
        }
    }
    
    // MARK: - SSH Section
    
    private var sshSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("SSH Keys")
                        .font(DesignTokens.Typography.title3)
                    Text("Manage SSH keys for Git authentication")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Button {
                    viewModel.showGenerateSSHSheet = true
                } label: {
                    Label("Generate New Key", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // SSH Keys list
            if viewModel.sshKeys.isEmpty {
                emptySSHView
            } else {
                ForEach(viewModel.sshKeys) { key in
                    SSHKeyRow(key: key, onCopy: {
                        viewModel.copyPublicKey(key)
                    }, onDelete: {
                        viewModel.deleteSSHKey(key)
                    })
                }
            }
            
            Spacer()
        }
        .sheet(isPresented: $viewModel.showGenerateSSHSheet) {
            GenerateSSHKeySheet(viewModel: viewModel)
        }
    }
    
    private var emptySSHView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "key")
                // TODO: Replace with appropriate Typography token when available for large icons
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(AppTheme.textPrimary)

            Text("No SSH Keys Found")
                .font(DesignTokens.Typography.headline)

            Text("Generate a new SSH key to authenticate with Git servers")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Button("Generate SSH Key") {
                viewModel.showGenerateSSHSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xxl + 8)
    }
    
    // MARK: - GPG Section
    
    private var gpgSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("GPG Keys")
                        .font(DesignTokens.Typography.title3)
                    Text("Manage GPG keys for commit signing")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Button {
                    viewModel.showGenerateGPGSheet = true
                } label: {
                    Label("Generate New Key", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // GPG status
            if viewModel.gpgInstalled {
                gpgInstalledContent
            } else {
                gpgNotInstalledView
            }
            
            Spacer()
        }
        .sheet(isPresented: $viewModel.showGenerateGPGSheet) {
            GenerateGPGKeySheet(viewModel: viewModel)
        }
    }
    
    private var gpgInstalledContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // GPG Keys list
            if viewModel.gpgKeys.isEmpty {
                emptyGPGView
            } else {
                ForEach(viewModel.gpgKeys) { key in
                    GPGKeyRow(key: key, onCopy: {
                        viewModel.copyGPGKey(key)
                    }, onDelete: {
                        viewModel.deleteGPGKey(key)
                    })
                }
            }

            // Signing configuration
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Commit Signing")
                    .font(DesignTokens.Typography.headline)
                
                Toggle("Sign commits by default", isOn: $viewModel.signCommitsByDefault)
                    .onChange(of: viewModel.signCommitsByDefault) { _, newValue in
                        Task { await viewModel.setSignCommits(newValue) }
                    }
                
                if !viewModel.gpgKeys.isEmpty {
                    Picker("Default signing key", selection: $viewModel.defaultSigningKey) {
                        Text("None").tag("")
                        ForEach(viewModel.gpgKeys) { key in
                            Text("\(key.email) (\(key.keyId.suffix(8)))").tag(key.keyId)
                        }
                    }
                    .onChange(of: viewModel.defaultSigningKey) { _, newValue in
                        Task { await viewModel.setDefaultSigningKey(newValue) }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
    }
    
    private var gpgNotInstalledView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                // TODO: Replace with appropriate Typography token when available for large icons
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(AppTheme.warning)

            Text("GPG Not Installed")
                .font(DesignTokens.Typography.headline)

            Text("Install GPG to sign your commits.\nYou can install it via Homebrew:")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("brew install gnupg")
                .font(DesignTokens.Typography.callout)
                .fontDesign(.monospaced)
                .padding(DesignTokens.Spacing.sm)
                .background(AppTheme.textMuted.opacity(0.2))
                .cornerRadius(DesignTokens.CornerRadius.sm)

            Button("Check Again") {
                Task { await viewModel.checkGPGInstallation() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xxl + 8)
    }
    
    private var emptyGPGView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "signature")
                // TODO: Replace with appropriate Typography token when available for large icons
                .font(.system(size: DesignTokens.Size.iconXL))
                .foregroundColor(AppTheme.textPrimary)

            Text("No GPG Keys Found")
                .font(DesignTokens.Typography.headline)

            Text("Generate a GPG key to sign your commits")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)

            Button("Generate GPG Key") {
                viewModel.showGenerateGPGSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xxl + 8)
    }
}

// MARK: - Types

enum SecurityTab: CaseIterable {
    case ssh, gpg
    
    var title: String {
        switch self {
        case .ssh: return "SSH Keys"
        case .gpg: return "GPG Keys"
        }
    }
    
    var icon: String {
        switch self {
        case .ssh: return "key.horizontal"
        case .gpg: return "signature"
        }
    }
}

struct SSHKey: Identifiable {
    let id: String
    let name: String
    let type: String // ed25519, rsa, etc
    let fingerprint: String
    let publicKeyPath: String
    let privateKeyPath: String
    let createdAt: Date?
}

struct GPGKey: Identifiable {
    let id: String
    let keyId: String
    let name: String
    let email: String
    let createdAt: Date?
    let expiresAt: Date?
    let isExpired: Bool
}

// MARK: - Row Views

struct SSHKeyRow: View {
    let key: SSHKey
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Text(key.name)
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.medium)
                    Text(key.type.uppercased())
                        .font(DesignTokens.Typography.caption2)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(AppTheme.info.opacity(0.2))
                        .foregroundColor(AppTheme.accent)
                        .cornerRadius(DesignTokens.CornerRadius.sm - 1)
                }
                Text(key.fingerprint)
                    .font(DesignTokens.Typography.caption2)
                    .fontDesign(.monospaced)
                    .foregroundColor(AppTheme.textPrimary)
            }
            
            Spacer()

            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Copy public key")

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .foregroundColor(AppTheme.error)
            }
            .buttonStyle(.plain)
            .help("Delete key")
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }
}

struct GPGKeyRow: View {
    let key: GPGKey
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Text(key.name)
                        .font(DesignTokens.Typography.callout)
                        .fontWeight(.medium)
                    if key.isExpired {
                        Text("EXPIRED")
                            .font(.system(size: 9)) // Badge - intentionally small
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 1)
                            .background(AppTheme.error.opacity(0.2))
                            .foregroundColor(AppTheme.error)
                            .cornerRadius(DesignTokens.CornerRadius.sm - 1)
                    }
                }
                Text(key.email)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Key ID: \(key.keyId.suffix(8))")
                    .font(DesignTokens.Typography.caption2)
                    .fontDesign(.monospaced)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Copy public key")

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .foregroundColor(AppTheme.error)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(DesignTokens.CornerRadius.lg)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }
}

// MARK: - Generate Sheets

struct GenerateSSHKeySheet: View {
    @ObservedObject var viewModel: GPGSSHViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var keyName = ""
    @State private var keyType = "ed25519"
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Generate SSH Key")
                .font(DesignTokens.Typography.title3)
            
            Form {
                TextField("Key Name", text: $keyName)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Key Type", selection: $keyType) {
                    Text("Ed25519 (Recommended)").tag("ed25519")
                    Text("RSA 4096").tag("rsa")
                }
                
                SecureField("Passphrase (optional)", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Confirm Passphrase", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Button("Generate") {
                    Task {
                        await viewModel.generateSSHKey(
                            name: keyName.isEmpty ? "id_\(keyType)" : keyName,
                            type: keyType,
                            passphrase: passphrase.isEmpty ? nil : passphrase
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(passphrase != confirmPassphrase)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 400)
    }
}

struct GenerateGPGKeySheet: View {
    @ObservedObject var viewModel: GPGSSHViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var passphrase = ""
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Generate GPG Key")
                .font(DesignTokens.Typography.title3)
            
            Form {
                TextField("Full Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Passphrase", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Button("Generate") {
                    Task {
                        await viewModel.generateGPGKey(name: name, email: email, passphrase: passphrase)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || email.isEmpty || passphrase.isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 400)
    }
}

// MARK: - View Model

@MainActor
class GPGSSHViewModel: ObservableObject {
    @Published var sshKeys: [SSHKey] = []
    @Published var gpgKeys: [GPGKey] = []
    @Published var gpgInstalled = false
    @Published var signCommitsByDefault = false
    @Published var defaultSigningKey = ""
    @Published var showGenerateSSHSheet = false
    @Published var showGenerateGPGSheet = false
    
    func loadKeys() async {
        await loadSSHKeys()
        await checkGPGInstallation()
        if gpgInstalled {
            await loadGPGKeys()
            await loadGPGConfig()
        }
    }
    
    // MARK: - SSH
    
    func loadSSHKeys() async {
        let sshDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sshDir, includingPropertiesForKeys: [.creationDateKey])
            
            var keys: [SSHKey] = []
            
            for file in files where file.pathExtension == "pub" {
                let name = file.deletingPathExtension().lastPathComponent
                let privateKeyPath = file.deletingPathExtension().path
                
                // Get fingerprint
                if let fingerprint = try? await ShellExecutor.shared.execute(
                    "ssh-keygen -lf '\(file.path)'"
                ).output.trimmingCharacters(in: .whitespacesAndNewlines) {
                    
                    let parts = fingerprint.split(separator: " ")
                    let keyType = parts.count > 3 ? String(parts[3]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "") : "unknown"
                    
                    let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                    let createdAt = attributes?[.creationDate] as? Date
                    
                    keys.append(SSHKey(
                        id: name,
                        name: name,
                        type: keyType.lowercased(),
                        fingerprint: fingerprint,
                        publicKeyPath: file.path,
                        privateKeyPath: privateKeyPath,
                        createdAt: createdAt
                    ))
                }
            }
            
            sshKeys = keys
        } catch {
            sshKeys = []
        }
    }
    
    func generateSSHKey(name: String, type: String, passphrase: String?) async {
        let sshDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        let keyPath = sshDir.appendingPathComponent(name).path
        
        var command = "ssh-keygen -t \(type) -f '\(keyPath)'"
        if let pass = passphrase, !pass.isEmpty {
            command += " -N '\(pass)'"
        } else {
            command += " -N ''"
        }
        
        if type == "rsa" {
            command += " -b 4096"
        }
        
        _ = try? await ShellExecutor.shared.execute(command)
        await loadSSHKeys()
    }
    
    func copyPublicKey(_ key: SSHKey) {
        if let content = try? String(contentsOfFile: key.publicKeyPath) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        }
    }
    
    func deleteSSHKey(_ key: SSHKey) {
        try? FileManager.default.removeItem(atPath: key.publicKeyPath)
        try? FileManager.default.removeItem(atPath: key.privateKeyPath)
        Task { await loadSSHKeys() }
    }
    
    // MARK: - GPG
    
    func checkGPGInstallation() async {
        let result = try? await ShellExecutor.shared.execute("which gpg")
        gpgInstalled = !(result?.output.isEmpty ?? true)
    }
    
    func loadGPGKeys() async {
        guard gpgInstalled else { return }
        
        let result = try? await ShellExecutor.shared.execute(
            "gpg --list-secret-keys --keyid-format LONG 2>/dev/null"
        )
        
        guard let output = result?.output, !output.isEmpty else {
            gpgKeys = []
            return
        }
        
        // Parse GPG output
        var keys: [GPGKey] = []
        var currentKeyId = ""
        var currentName = ""
        var currentEmail = ""
        
        for line in output.components(separatedBy: "\n") {
            if line.contains("sec ") {
                // Extract key ID
                if let match = line.range(of: #"/[A-F0-9]{16}"#, options: .regularExpression) {
                    currentKeyId = String(line[match]).replacingOccurrences(of: "/", with: "")
                }
            } else if line.contains("uid ") {
                // Extract name and email
                let cleaned = line.replacingOccurrences(of: "uid", with: "").trimmingCharacters(in: .whitespaces)
                if let emailMatch = cleaned.range(of: #"<[^>]+>"#, options: .regularExpression) {
                    currentEmail = String(cleaned[emailMatch]).replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
                    currentName = String(cleaned[..<emailMatch.lowerBound]).trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "[ultimate]", with: "")
                        .replacingOccurrences(of: "[full]", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                
                if !currentKeyId.isEmpty {
                    keys.append(GPGKey(
                        id: currentKeyId,
                        keyId: currentKeyId,
                        name: currentName,
                        email: currentEmail,
                        createdAt: nil,
                        expiresAt: nil,
                        isExpired: false
                    ))
                    currentKeyId = ""
                }
            }
        }
        
        gpgKeys = keys
    }
    
    func loadGPGConfig() async {
        let signResult = try? await ShellExecutor.shared.execute("git config --global commit.gpgsign")
        signCommitsByDefault = signResult?.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        
        let keyResult = try? await ShellExecutor.shared.execute("git config --global user.signingkey")
        defaultSigningKey = keyResult?.output.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    func generateGPGKey(name: String, email: String, passphrase: String) async {
        let batchConfig = """
        Key-Type: RSA
        Key-Length: 4096
        Name-Real: \(name)
        Name-Email: \(email)
        Passphrase: \(passphrase)
        Expire-Date: 0
        %commit
        """
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("gpg-batch.txt")
        try? batchConfig.write(to: tempFile, atomically: true, encoding: .utf8)
        
        _ = try? await ShellExecutor.shared.execute("gpg --batch --generate-key '\(tempFile.path)'")
        try? FileManager.default.removeItem(at: tempFile)
        
        await loadGPGKeys()
    }
    
    func copyGPGKey(_ key: GPGKey) {
        if let result = try? ShellExecutor.shared.executeSync("gpg --armor --export \(key.keyId)") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.output, forType: .string)
        }
    }
    
    func deleteGPGKey(_ key: GPGKey) {
        _ = try? ShellExecutor.shared.executeSync("gpg --batch --yes --delete-secret-keys \(key.keyId)")
        _ = try? ShellExecutor.shared.executeSync("gpg --batch --yes --delete-keys \(key.keyId)")
        Task { await loadGPGKeys() }
    }
    
    func setSignCommits(_ enabled: Bool) async {
        _ = try? await ShellExecutor.shared.execute("git config --global commit.gpgsign \(enabled)")
    }
    
    func setDefaultSigningKey(_ keyId: String) async {
        if keyId.isEmpty {
            _ = try? await ShellExecutor.shared.execute("git config --global --unset user.signingkey")
        } else {
            _ = try? await ShellExecutor.shared.execute("git config --global user.signingkey \(keyId)")
        }
    }
}
