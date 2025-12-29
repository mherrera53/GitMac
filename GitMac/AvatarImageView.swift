import SwiftUI
import AppKit
import CryptoKit

// MARK: - Avatar cache (memoria + disco)
actor AvatarCache {
    static let shared = AvatarCache()

    private let memory = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let folderURL: URL

    init() {
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleId = Bundle.main.bundleIdentifier ?? "GitMac"
        let cacheFolder = appSupport?
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent("AvatarCache", isDirectory: true)

        folderURL = cacheFolder ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AvatarCache", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    private func diskPath(for key: String) -> URL {
        folderURL.appendingPathComponent(key + ".png")
    }

    func image(for key: String) -> NSImage? {
        if let img = memory.object(forKey: key as NSString) {
            return img
        }
        let path = diskPath(for: key)
        if let data = try? Data(contentsOf: path), let img = NSImage(data: data) {
            memory.setObject(img, forKey: key as NSString)
            return img
        }
        return nil
    }

    func store(_ image: NSImage, for key: String) {
        memory.setObject(image, forKey: key as NSString)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: diskPath(for: key))
    }
}

// MARK: - Avatar Image View
struct AvatarImageView: View {
    let email: String
    let size: CGFloat
    let fallbackInitial: String

    @State private var nsImage: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback: inicial con color determinista
                ZStack {
                    Circle().fill(fallbackColor)
                    Text(fallbackInitial.uppercased())
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: cacheKey) {
            await loadAvatar()
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var emailHash: String {
        // Gravatar usa MD5 del email en minúsculas sin espacios
        let data = normalizedEmail.data(using: .utf8) ?? Data()
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    private var pixelSize: Int {
        // Retina-friendly: pide 2x
        return Int(size * 2.0)
    }

    private var cacheKey: String {
        "\(emailHash)_\(pixelSize)"
    }

    private var fallbackColor: Color {
        // Color determinista según hash
        guard let first = emailHash.first else { return .gray }
        let value = Double(first.unicodeScalars.first?.value ?? 0) / 255.0
        return Color(hue: value, saturation: 0.6, brightness: 0.8)
    }

    private func gravatarURL() -> URL? {
        guard !emailHash.isEmpty else { return nil }
        return URL(string: "https://www.gravatar.com/avatar/\(emailHash)?s=\(pixelSize)&d=404")
    }

    private func loadAvatar() async {
        guard !normalizedEmail.isEmpty else { return }

        // Check cache first
        if let cached = await AvatarCache.shared.image(for: cacheKey) {
            nsImage = cached
            return
        }

        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        // Try to get avatar from AvatarService (GitHub → Gravatar → Identicon)
        let token = try? await KeychainManager.shared.getGitHubToken()
        if let avatarURL = await AvatarService.shared.getAvatarURL(for: normalizedEmail, githubToken: token) {
            do {
                let (data, response) = try await URLSession.shared.data(from: avatarURL, delegate: nil)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let img = NSImage(data: data) {
                    await AvatarCache.shared.store(img, for: cacheKey)
                    nsImage = img
                    return
                }
            } catch {
                NSLog("⚠️ Failed to load avatar from \(avatarURL): \(error)")
            }
        }

        // Final fallback: try Gravatar directly
        if let url = gravatarURL() {
            do {
                let (data, response) = try await URLSession.shared.data(from: url, delegate: nil)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let img = NSImage(data: data) {
                    await AvatarCache.shared.store(img, for: cacheKey)
                    nsImage = img
                }
            } catch {
                // Use fallback initial circle
            }
        }
    }
}
