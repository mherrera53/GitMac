import SwiftUI
import Combine
import AppKit

/// Theme Manager - Sistema completo de temas para GitMac
/// Soporta temas predefinidos y personalizados
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: Theme = .system
    @Published var customColors: CustomColorScheme?
    @Published var appearance: NSAppearance?
    
    private let defaults = UserDefaults.standard
    private let themeKey = "selectedTheme"
    private let customColorsKey = "customColors"
    
    private init() {
        NSLog("🔧 [ThemeManager] Initializing ThemeManager")
        loadSavedTheme()
        applyTheme()
        NSLog("🔧 [ThemeManager] Initialization complete")
    }
    
    // MARK: - Theme Application
    
    func setTheme(_ theme: Theme) {
        NSLog("🎨 [ThemeManager] setTheme called with: \(theme.rawValue)")
        currentTheme = theme
        saveTheme()
        applyTheme()

        // Notify all windows
        NotificationCenter.default.post(name: .themeDidChange, object: theme)
        NSLog("📢 [ThemeManager] Theme change notification posted")
    }
    
    func applyTheme() {
        NSLog("🎭 [ThemeManager] applyTheme() called for theme: \(currentTheme.rawValue)")

        switch currentTheme {
        case .system:
            appearance = nil
            NSApp.appearance = nil

        case .light:
            appearance = NSAppearance(named: .aqua)
            NSApp.appearance = appearance

        case .dark:
            appearance = NSAppearance(named: .darkAqua)
            NSApp.appearance = appearance

        case .custom:
            // Custom theme uses system appearance but custom colors
            appearance = nil
            NSApp.appearance = nil
        }

        // Apply to all windows
        for window in NSApp.windows {
            window.appearance = appearance
            NSLog("🪟 [ThemeManager] Applied theme to window: \(window.title)")
        }

        NSLog("✨ [ThemeManager] Theme applied successfully")
    }
    
    // MARK: - Custom Colors
    
    func setCustomColors(_ colors: CustomColorScheme) {
        customColors = colors
        currentTheme = .custom
        saveCustomColors()
        saveTheme()
        applyTheme()
    }
    
    func resetToDefault() {
        currentTheme = .system
        customColors = nil
        saveTheme()
        applyTheme()
    }
    
    // MARK: - Persistence
    
    private func saveTheme() {
        defaults.set(currentTheme.rawValue, forKey: themeKey)
        defaults.synchronize()
        NSLog("💾 [ThemeManager] Theme saved to UserDefaults: \(currentTheme.rawValue)")
        print("💾 Theme saved to UserDefaults: \(currentTheme)")

        // Verify it was saved
        if let saved = defaults.string(forKey: themeKey) {
            NSLog("✓ [ThemeManager] Verified saved theme: \(saved)")
        } else {
            NSLog("✗ [ThemeManager] Failed to save theme!")
        }
    }
    
    private func loadSavedTheme() {
        NSLog("🔍 [ThemeManager] Loading saved theme from key: \(themeKey)")
        if let themeRaw = defaults.string(forKey: themeKey),
           let theme = Theme(rawValue: themeRaw) {
            currentTheme = theme
            NSLog("✅ [ThemeManager] Theme loaded from UserDefaults: \(theme.rawValue)")
            print("✅ Theme loaded from UserDefaults: \(theme)")
        } else {
            NSLog("⚠️ [ThemeManager] No saved theme found, using default: \(currentTheme.rawValue)")
            print("⚠️ No saved theme found, using default: \(currentTheme)")
        }

        loadCustomColors()
    }
    
    private func saveCustomColors() {
        guard let colors = customColors else { return }
        
        if let encoded = try? JSONEncoder().encode(colors) {
            defaults.set(encoded, forKey: customColorsKey)
        }
    }
    
    private func loadCustomColors() {
        guard let data = defaults.data(forKey: customColorsKey),
              let colors = try? JSONDecoder().decode(CustomColorScheme.self, from: data) else {
            return
        }

        customColors = colors
    }

    // MARK: - JSON Import/Export

    func exportThemeToJSON() throws -> String {
        let themeData = ThemeExportData(
            name: "Custom Theme",
            version: "1.0",
            colors: colors
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(themeData)

        guard let json = String(data: data, encoding: .utf8) else {
            throw ThemeError.encodingFailed
        }

        return json
    }

    func importThemeFromJSON(_ json: String) throws {
        guard let data = json.data(using: .utf8) else {
            throw ThemeError.invalidJSON
        }

        let decoder = JSONDecoder()
        let themeData = try decoder.decode(ThemeExportData.self, from: data)

        // Convert ColorScheme to CustomColorScheme
        let customScheme = CustomColorScheme(
            background: themeData.colors.background,
            backgroundSecondary: themeData.colors.backgroundSecondary,
            backgroundTertiary: themeData.colors.backgroundTertiary,
            text: themeData.colors.text,
            textSecondary: themeData.colors.textSecondary,
            textMuted: themeData.colors.textMuted,
            accent: themeData.colors.accent,
            accentHover: themeData.colors.accentHover,
            gitAdded: themeData.colors.gitAdded,
            gitModified: themeData.colors.gitModified,
            gitDeleted: themeData.colors.gitDeleted,
            gitRenamed: themeData.colors.gitRenamed,
            gitConflict: themeData.colors.gitConflict,
            gitUntracked: themeData.colors.gitUntracked,
            branchLocal: themeData.colors.branchLocal,
            branchRemote: themeData.colors.branchRemote,
            branchCurrent: themeData.colors.branchCurrent,
            graphLine1: themeData.colors.graphLine1,
            graphLine2: themeData.colors.graphLine2,
            graphLine3: themeData.colors.graphLine3,
            graphLine4: themeData.colors.graphLine4,
            graphLine5: themeData.colors.graphLine5,
            success: themeData.colors.success,
            warning: themeData.colors.warning,
            error: themeData.colors.error,
            info: themeData.colors.info
        )

        setCustomColors(customScheme)
    }

    func exportThemeToFile() {
        do {
            let json = try exportThemeToJSON()

            let savePanel = NSSavePanel()
            savePanel.title = "Export Theme"
            savePanel.message = "Choose where to save your theme"
            savePanel.nameFieldStringValue = "GitMac-Theme.json"
            savePanel.allowedContentTypes = [.json]
            savePanel.canCreateDirectories = true

            savePanel.begin { response in
                guard response == .OK, let url = savePanel.url else { return }

                do {
                    try json.write(to: url, atomically: true, encoding: .utf8)
                    print("✅ Theme exported successfully to: \(url.path)")
                } catch {
                    print("❌ Failed to write theme file: \(error)")
                }
            }
        } catch {
            print("❌ Failed to export theme: \(error)")
        }
    }

    func importThemeFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Theme"
        openPanel.message = "Choose a theme JSON file to import"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            guard response == .OK, let url = openPanel.urls.first else { return }

            do {
                let json = try String(contentsOf: url, encoding: .utf8)
                try self.importThemeFromJSON(json)
                print("✅ Theme imported successfully from: \(url.path)")
            } catch {
                print("❌ Failed to import theme: \(error)")
            }
        }
    }

    // MARK: - Theme Colors (Computed)
    
    var colors: ColorScheme {
        if currentTheme == .custom, let custom = customColors {
            return ColorScheme(custom: custom)
        }
        
        return ColorScheme.default(for: currentTheme)
    }
}

// MARK: - Theme Enum

enum Theme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case custom
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .custom: return "paintbrush.fill"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "Match system appearance"
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        case .custom: return "Use custom colors"
        }
    }
}

// MARK: - Color Scheme

struct ColorScheme: Codable {
    // UI Colors
    let background: CodableColor
    let backgroundSecondary: CodableColor
    let backgroundTertiary: CodableColor
    
    // Text Colors
    let text: CodableColor
    let textSecondary: CodableColor
    let textMuted: CodableColor
    
    // Accent Colors
    let accent: CodableColor
    let accentHover: CodableColor
    
    // Git Colors
    let gitAdded: CodableColor
    let gitModified: CodableColor
    let gitDeleted: CodableColor
    let gitRenamed: CodableColor
    let gitConflict: CodableColor
    let gitUntracked: CodableColor
    
    // Branch Colors
    let branchLocal: CodableColor
    let branchRemote: CodableColor
    let branchCurrent: CodableColor
    
    // Graph Colors
    let graphLine1: CodableColor
    let graphLine2: CodableColor
    let graphLine3: CodableColor
    let graphLine4: CodableColor
    let graphLine5: CodableColor
    
    // Status Colors
    let success: CodableColor
    let warning: CodableColor
    let error: CodableColor
    let info: CodableColor

    // Diff Colors (for all diff views including Kaleidoscope)
    let diffAddition: CodableColor
    let diffDeletion: CodableColor
    let diffChange: CodableColor

    static func `default`(for theme: Theme) -> ColorScheme {
        switch theme {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return .system
        }
    }
    
    init(custom: CustomColorScheme) {
        // Detectar si el tema es claro u oscuro basado en la luminancia del fondo
        let isLightTheme = custom.background.isLight

        // Si el tema es claro, asegurar que los textos sean oscuros
        // Si el tema es oscuro, asegurar que los textos sean claros
        let adaptedText = isLightTheme ?
            CodableColor(hex: "#000000") : CodableColor(hex: "#FFFFFF")
        let adaptedTextSecondary = isLightTheme ?
            CodableColor(hex: "#666666") : CodableColor(hex: "#CCCCCC")
        let adaptedTextMuted = isLightTheme ?
            CodableColor(hex: "#999999") : CodableColor(hex: "#999999")

        self.background = custom.background
        self.backgroundSecondary = custom.backgroundSecondary
        self.backgroundTertiary = custom.backgroundTertiary
        self.text = adaptedText
        self.textSecondary = adaptedTextSecondary
        self.textMuted = adaptedTextMuted
        self.accent = custom.accent
        self.accentHover = custom.accentHover
        self.gitAdded = custom.gitAdded
        self.gitModified = custom.gitModified
        self.gitDeleted = custom.gitDeleted
        self.gitRenamed = custom.gitRenamed
        self.gitConflict = custom.gitConflict
        self.gitUntracked = custom.gitUntracked
        self.branchLocal = custom.branchLocal
        self.branchRemote = custom.branchRemote
        self.branchCurrent = custom.branchCurrent
        self.graphLine1 = custom.graphLine1
        self.graphLine2 = custom.graphLine2
        self.graphLine3 = custom.graphLine3
        self.graphLine4 = custom.graphLine4
        self.graphLine5 = custom.graphLine5
        self.success = custom.success
        self.warning = custom.warning
        self.error = custom.error
        self.info = custom.info

        // Use theme-appropriate diff colors or fallback to semantic colors
        self.diffAddition = isLightTheme ?
            CodableColor(hex: "#34C759") : CodableColor(hex: "#34C759")  // macOS green
        self.diffDeletion = isLightTheme ?
            CodableColor(hex: "#FF3B30") : CodableColor(hex: "#FF3B30")  // macOS red
        self.diffChange = isLightTheme ?
            CodableColor(hex: "#007AFF") : CodableColor(hex: "#007AFF")  // macOS blue
    }

    init(background: CodableColor, backgroundSecondary: CodableColor, backgroundTertiary: CodableColor,
         text: CodableColor, textSecondary: CodableColor, textMuted: CodableColor,
         accent: CodableColor, accentHover: CodableColor,
         gitAdded: CodableColor, gitModified: CodableColor, gitDeleted: CodableColor,
         gitRenamed: CodableColor, gitConflict: CodableColor, gitUntracked: CodableColor,
         branchLocal: CodableColor, branchRemote: CodableColor, branchCurrent: CodableColor,
         graphLine1: CodableColor, graphLine2: CodableColor, graphLine3: CodableColor,
         graphLine4: CodableColor, graphLine5: CodableColor,
         success: CodableColor, warning: CodableColor, error: CodableColor, info: CodableColor,
         diffAddition: CodableColor, diffDeletion: CodableColor, diffChange: CodableColor) {
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.backgroundTertiary = backgroundTertiary
        self.text = text
        self.textSecondary = textSecondary
        self.textMuted = textMuted
        self.accent = accent
        self.accentHover = accentHover
        self.gitAdded = gitAdded
        self.gitModified = gitModified
        self.gitDeleted = gitDeleted
        self.gitRenamed = gitRenamed
        self.gitConflict = gitConflict
        self.gitUntracked = gitUntracked
        self.branchLocal = branchLocal
        self.branchRemote = branchRemote
        self.branchCurrent = branchCurrent
        self.graphLine1 = graphLine1
        self.graphLine2 = graphLine2
        self.graphLine3 = graphLine3
        self.graphLine4 = graphLine4
        self.graphLine5 = graphLine5
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.diffAddition = diffAddition
        self.diffDeletion = diffDeletion
        self.diffChange = diffChange
    }

    // Light Theme
    static let light = ColorScheme(
        background: CodableColor(hex: "#FFFFFF"),
        backgroundSecondary: CodableColor(hex: "#F5F5F5"),
        backgroundTertiary: CodableColor(hex: "#EEEEEE"),
        text: CodableColor(hex: "#000000"),
        textSecondary: CodableColor(hex: "#666666"),
        textMuted: CodableColor(hex: "#999999"),
        accent: CodableColor(hex: "#007AFF"),
        accentHover: CodableColor(hex: "#0051D5"),
        gitAdded: CodableColor(hex: "#28A745"),
        gitModified: CodableColor(hex: "#FF9800"),
        gitDeleted: CodableColor(hex: "#DC3545"),
        gitRenamed: CodableColor(hex: "#2196F3"),
        gitConflict: CodableColor(hex: "#E91E63"),
        gitUntracked: CodableColor(hex: "#9E9E9E"),
        branchLocal: CodableColor(hex: "#28A745"),
        branchRemote: CodableColor(hex: "#2196F3"),
        branchCurrent: CodableColor(hex: "#FF9800"),
        graphLine1: CodableColor(hex: "#2196F3"),
        graphLine2: CodableColor(hex: "#4CAF50"),
        graphLine3: CodableColor(hex: "#FF9800"),
        graphLine4: CodableColor(hex: "#9C27B0"),
        graphLine5: CodableColor(hex: "#F44336"),
        success: CodableColor(hex: "#28A745"),
        warning: CodableColor(hex: "#FF9800"),
        error: CodableColor(hex: "#DC3545"),
        info: CodableColor(hex: "#2196F3"),
        diffAddition: CodableColor(hex: "#34C759"),  // macOS green
        diffDeletion: CodableColor(hex: "#FF3B30"),  // macOS red
        diffChange: CodableColor(hex: "#007AFF")     // macOS blue
    )

    // Dark Theme
    static let dark = ColorScheme(
        background: CodableColor(hex: "#1E1E1E"),
        backgroundSecondary: CodableColor(hex: "#252526"),
        backgroundTertiary: CodableColor(hex: "#2D2D30"),
        text: CodableColor(hex: "#FFFFFF"),
        textSecondary: CodableColor(hex: "#CCCCCC"),
        textMuted: CodableColor(hex: "#999999"),
        accent: CodableColor(hex: "#007ACC"),
        accentHover: CodableColor(hex: "#0098FF"),
        gitAdded: CodableColor(hex: "#4EC9B0"),
        gitModified: CodableColor(hex: "#CE9178"),
        gitDeleted: CodableColor(hex: "#F48771"),
        gitRenamed: CodableColor(hex: "#569CD6"),
        gitConflict: CodableColor(hex: "#F44747"),
        gitUntracked: CodableColor(hex: "#858585"),
        branchLocal: CodableColor(hex: "#4EC9B0"),
        branchRemote: CodableColor(hex: "#569CD6"),
        branchCurrent: CodableColor(hex: "#CE9178"),
        graphLine1: CodableColor(hex: "#569CD6"),
        graphLine2: CodableColor(hex: "#4EC9B0"),
        graphLine3: CodableColor(hex: "#CE9178"),
        graphLine4: CodableColor(hex: "#C586C0"),
        graphLine5: CodableColor(hex: "#F48771"),
        success: CodableColor(hex: "#4EC9B0"),
        warning: CodableColor(hex: "#CE9178"),
        error: CodableColor(hex: "#F48771"),
        info: CodableColor(hex: "#569CD6"),
        diffAddition: CodableColor(hex: "#34C759"),  // macOS green
        diffDeletion: CodableColor(hex: "#FF3B30"),  // macOS red
        diffChange: CodableColor(hex: "#007AFF")     // macOS blue
    )

    // System (adaptive)
    static let system = ColorScheme(
        background: CodableColor(hex: "#FFFFFF"),
        backgroundSecondary: CodableColor(hex: "#F5F5F5"),
        backgroundTertiary: CodableColor(hex: "#EEEEEE"),
        text: CodableColor(hex: "#000000"),
        textSecondary: CodableColor(hex: "#666666"),
        textMuted: CodableColor(hex: "#999999"),
        accent: CodableColor(hex: "#007AFF"),
        accentHover: CodableColor(hex: "#0051D5"),
        gitAdded: CodableColor(hex: "#28A745"),
        gitModified: CodableColor(hex: "#FF9800"),
        gitDeleted: CodableColor(hex: "#DC3545"),
        gitRenamed: CodableColor(hex: "#2196F3"),
        gitConflict: CodableColor(hex: "#E91E63"),
        gitUntracked: CodableColor(hex: "#9E9E9E"),
        branchLocal: CodableColor(hex: "#28A745"),
        branchRemote: CodableColor(hex: "#2196F3"),
        branchCurrent: CodableColor(hex: "#FF9800"),
        graphLine1: CodableColor(hex: "#2196F3"),
        graphLine2: CodableColor(hex: "#4CAF50"),
        graphLine3: CodableColor(hex: "#FF9800"),
        graphLine4: CodableColor(hex: "#9C27B0"),
        graphLine5: CodableColor(hex: "#F44336"),
        success: CodableColor(hex: "#28A745"),
        warning: CodableColor(hex: "#FF9800"),
        error: CodableColor(hex: "#DC3545"),
        info: CodableColor(hex: "#2196F3"),
        diffAddition: CodableColor(hex: "#34C759"),  // macOS green
        diffDeletion: CodableColor(hex: "#FF3B30"),  // macOS red
        diffChange: CodableColor(hex: "#007AFF")     // macOS blue
    )
}

// MARK: - Custom Color Scheme (User-editable)

struct CustomColorScheme: Codable, Equatable {
    var background: CodableColor
    var backgroundSecondary: CodableColor
    var backgroundTertiary: CodableColor
    var text: CodableColor
    var textSecondary: CodableColor
    var textMuted: CodableColor
    var accent: CodableColor
    var accentHover: CodableColor
    var gitAdded: CodableColor
    var gitModified: CodableColor
    var gitDeleted: CodableColor
    var gitRenamed: CodableColor
    var gitConflict: CodableColor
    var gitUntracked: CodableColor
    var branchLocal: CodableColor
    var branchRemote: CodableColor
    var branchCurrent: CodableColor
    var graphLine1: CodableColor
    var graphLine2: CodableColor
    var graphLine3: CodableColor
    var graphLine4: CodableColor
    var graphLine5: CodableColor
    var success: CodableColor
    var warning: CodableColor
    var error: CodableColor
    var info: CodableColor
    
    static let `default` = CustomColorScheme(
        background: CodableColor(hex: "#FFFFFF"),
        backgroundSecondary: CodableColor(hex: "#F5F5F5"),
        backgroundTertiary: CodableColor(hex: "#EEEEEE"),
        text: CodableColor(hex: "#000000"),
        textSecondary: CodableColor(hex: "#666666"),
        textMuted: CodableColor(hex: "#999999"),
        accent: CodableColor(hex: "#007AFF"),
        accentHover: CodableColor(hex: "#0051D5"),
        gitAdded: CodableColor(hex: "#28A745"),
        gitModified: CodableColor(hex: "#FF9800"),
        gitDeleted: CodableColor(hex: "#DC3545"),
        gitRenamed: CodableColor(hex: "#2196F3"),
        gitConflict: CodableColor(hex: "#E91E63"),
        gitUntracked: CodableColor(hex: "#9E9E9E"),
        branchLocal: CodableColor(hex: "#28A745"),
        branchRemote: CodableColor(hex: "#2196F3"),
        branchCurrent: CodableColor(hex: "#FF9800"),
        graphLine1: CodableColor(hex: "#2196F3"),
        graphLine2: CodableColor(hex: "#4CAF50"),
        graphLine3: CodableColor(hex: "#FF9800"),
        graphLine4: CodableColor(hex: "#9C27B0"),
        graphLine5: CodableColor(hex: "#F44336"),
        success: CodableColor(hex: "#28A745"),
        warning: CodableColor(hex: "#FF9800"),
        error: CodableColor(hex: "#DC3545"),
        info: CodableColor(hex: "#2196F3")
    )
}

// MARK: - Codable Color

struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(_ color: Color) {
        // Convert to NSColor using the sRGB color space
        if let nsColor = NSColor(color).usingColorSpace(.sRGB) {
            self.red = Double(nsColor.redComponent)
            self.green = Double(nsColor.greenComponent)
            self.blue = Double(nsColor.blueComponent)
            self.alpha = Double(nsColor.alphaComponent)
        } else {
            // Fallback for colors that can't be converted
            self.red = 0.5
            self.green = 0.5
            self.blue = 0.5
            self.alpha = 1.0
        }
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        
        self.red = Double(r) / 255.0
        self.green = Double(g) / 255.0
        self.blue = Double(b) / 255.0
        self.alpha = 1.0
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var hexString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Calculate relative luminance using WCAG formula
    var luminance: Double {
        let r = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        let g = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        let b = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Returns true if this color is light (luminance > 0.5)
    var isLight: Bool {
        return luminance > 0.5
    }
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Appearance")
                .font(.title2)
                .fontWeight(.bold)

            // Theme selector
            VStack(spacing: 12) {
                ForEach(Theme.allCases.filter { $0 != .custom }) { theme in
                    ThemeOptionButton(
                        theme: theme,
                        isSelected: themeManager.currentTheme == theme
                    ) {
                        themeManager.setTheme(theme)
                    }
                }

                // Custom theme button
                Button {
                    ThemeEditorWindowController.shared.showWindow()
                } label: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(AppTheme.accentPurple)

                        Text("Customize Colors...")

                        Spacer()

                        if themeManager.currentTheme == .custom {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.success)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.currentTheme == .custom ? AppTheme.accent : AppTheme.textSecondary.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Preview
            ThemePreview()
        }
        .padding()
    }
}

struct ThemeOptionButton: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: theme.icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(.headline)
                    
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.textSecondary.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        switch theme {
        case .system: return AppTheme.textSecondary
        case .light: return AppTheme.warning
        case .dark: return AppTheme.accent
        case .custom: return AppTheme.accent
        }
    }
}

struct ThemePreview: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
            
            VStack(spacing: 1) {
                // Background colors
                HStack(spacing: 1) {
                    ColorSwatch(color: themeManager.colors.background.color, label: "BG")
                    ColorSwatch(color: themeManager.colors.backgroundSecondary.color, label: "BG2")
                    ColorSwatch(color: themeManager.colors.backgroundTertiary.color, label: "BG3")
                }
                
                // Git colors
                HStack(spacing: 1) {
                    ColorSwatch(color: themeManager.colors.gitAdded.color, label: "Add")
                    ColorSwatch(color: themeManager.colors.gitModified.color, label: "Mod")
                    ColorSwatch(color: themeManager.colors.gitDeleted.color, label: "Del")
                    ColorSwatch(color: themeManager.colors.gitConflict.color, label: "Conf")
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.textSecondary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct ColorSwatch: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(height: 40)
            
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Custom Theme Editor

// Theme Palette Presets
struct ThemePalette: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let colors: CustomColorScheme

    static let allPalettes: [ThemePalette] = [
        // MARK: - Light Themes
        ThemePalette(
            name: "GitHub Light",
            description: "Clean and professional light theme - AAA contrast",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#ffffff"),
                backgroundSecondary: CodableColor(hex: "#f6f8fa"),
                backgroundTertiary: CodableColor(hex: "#e1e4e8"),
                text: CodableColor(hex: "#1f2328"),
                textSecondary: CodableColor(hex: "#4d5359"),
                textMuted: CodableColor(hex: "#656d76"),
                accent: CodableColor(hex: "#0969da"),
                accentHover: CodableColor(hex: "#0550ae"),
                gitAdded: CodableColor(hex: "#0d8a3d"),
                gitModified: CodableColor(hex: "#9a6700"),
                gitDeleted: CodableColor(hex: "#d1242f"),
                gitRenamed: CodableColor(hex: "#0969da"),
                gitConflict: CodableColor(hex: "#a40e26"),
                gitUntracked: CodableColor(hex: "#656d76"),
                branchLocal: CodableColor(hex: "#0d8a3d"),
                branchRemote: CodableColor(hex: "#0969da"),
                branchCurrent: CodableColor(hex: "#9a6700"),
                graphLine1: CodableColor(hex: "#0969da"),
                graphLine2: CodableColor(hex: "#0d8a3d"),
                graphLine3: CodableColor(hex: "#9a6700"),
                graphLine4: CodableColor(hex: "#8250df"),
                graphLine5: CodableColor(hex: "#d1242f"),
                success: CodableColor(hex: "#0d8a3d"),
                warning: CodableColor(hex: "#9a6700"),
                error: CodableColor(hex: "#d1242f"),
                info: CodableColor(hex: "#0969da")
            )
        ),
        ThemePalette(
            name: "Solarized Light",
            description: "Precision colors optimized for reduced eye strain - AAA",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#fdf6e3"),
                backgroundSecondary: CodableColor(hex: "#eee8d5"),
                backgroundTertiary: CodableColor(hex: "#e3ddc8"),
                text: CodableColor(hex: "#002b36"),
                textSecondary: CodableColor(hex: "#586e75"),
                textMuted: CodableColor(hex: "#657b83"),
                accent: CodableColor(hex: "#268bd2"),
                accentHover: CodableColor(hex: "#2075c7"),
                gitAdded: CodableColor(hex: "#859900"),
                gitModified: CodableColor(hex: "#b58900"),
                gitDeleted: CodableColor(hex: "#dc322f"),
                gitRenamed: CodableColor(hex: "#268bd2"),
                gitConflict: CodableColor(hex: "#d33682"),
                gitUntracked: CodableColor(hex: "#657b83"),
                branchLocal: CodableColor(hex: "#859900"),
                branchRemote: CodableColor(hex: "#268bd2"),
                branchCurrent: CodableColor(hex: "#b58900"),
                graphLine1: CodableColor(hex: "#268bd2"),
                graphLine2: CodableColor(hex: "#859900"),
                graphLine3: CodableColor(hex: "#b58900"),
                graphLine4: CodableColor(hex: "#6c71c4"),
                graphLine5: CodableColor(hex: "#dc322f"),
                success: CodableColor(hex: "#859900"),
                warning: CodableColor(hex: "#b58900"),
                error: CodableColor(hex: "#dc322f"),
                info: CodableColor(hex: "#268bd2")
            )
        ),

        // MARK: - Dark Themes
        ThemePalette(
            name: "GitHub Dark",
            description: "Classic GitHub dark theme - Maximum contrast AAA",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#0d1117"),
                backgroundSecondary: CodableColor(hex: "#161b22"),
                backgroundTertiary: CodableColor(hex: "#21262d"),
                text: CodableColor(hex: "#f0f6fc"),
                textSecondary: CodableColor(hex: "#c9d1d9"),
                textMuted: CodableColor(hex: "#8b949e"),
                accent: CodableColor(hex: "#58a6ff"),
                accentHover: CodableColor(hex: "#79c0ff"),
                gitAdded: CodableColor(hex: "#56d364"),
                gitModified: CodableColor(hex: "#f0ce53"),
                gitDeleted: CodableColor(hex: "#ff7b72"),
                gitRenamed: CodableColor(hex: "#79c0ff"),
                gitConflict: CodableColor(hex: "#ff6e7a"),
                gitUntracked: CodableColor(hex: "#8b949e"),
                branchLocal: CodableColor(hex: "#56d364"),
                branchRemote: CodableColor(hex: "#79c0ff"),
                branchCurrent: CodableColor(hex: "#f0ce53"),
                graphLine1: CodableColor(hex: "#58a6ff"),
                graphLine2: CodableColor(hex: "#56d364"),
                graphLine3: CodableColor(hex: "#f0ce53"),
                graphLine4: CodableColor(hex: "#d2a8ff"),
                graphLine5: CodableColor(hex: "#ff7b72"),
                success: CodableColor(hex: "#56d364"),
                warning: CodableColor(hex: "#f0ce53"),
                error: CodableColor(hex: "#ff7b72"),
                info: CodableColor(hex: "#58a6ff")
            )
        ),
        ThemePalette(
            name: "Dracula",
            description: "Vibrant dark theme with maximum contrast - AAA",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#282a36"),
                backgroundSecondary: CodableColor(hex: "#21222c"),
                backgroundTertiary: CodableColor(hex: "#191a21"),
                text: CodableColor(hex: "#ffffff"),
                textSecondary: CodableColor(hex: "#e4e5f1"),
                textMuted: CodableColor(hex: "#a1a8c9"),
                accent: CodableColor(hex: "#bd93f9"),
                accentHover: CodableColor(hex: "#d0b4ff"),
                gitAdded: CodableColor(hex: "#50fa7b"),
                gitModified: CodableColor(hex: "#f1fa8c"),
                gitDeleted: CodableColor(hex: "#ff6e85"),
                gitRenamed: CodableColor(hex: "#8be9fd"),
                gitConflict: CodableColor(hex: "#ff79c6"),
                gitUntracked: CodableColor(hex: "#a1a8c9"),
                branchLocal: CodableColor(hex: "#50fa7b"),
                branchRemote: CodableColor(hex: "#8be9fd"),
                branchCurrent: CodableColor(hex: "#f1fa8c"),
                graphLine1: CodableColor(hex: "#bd93f9"),
                graphLine2: CodableColor(hex: "#50fa7b"),
                graphLine3: CodableColor(hex: "#ffb86c"),
                graphLine4: CodableColor(hex: "#ff79c6"),
                graphLine5: CodableColor(hex: "#8be9fd"),
                success: CodableColor(hex: "#50fa7b"),
                warning: CodableColor(hex: "#f1fa8c"),
                error: CodableColor(hex: "#ff6e85"),
                info: CodableColor(hex: "#8be9fd")
            )
        ),
        ThemePalette(
            name: "Nord",
            description: "Arctic theme with pristine contrast - AAA compliant",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#2e3440"),
                backgroundSecondary: CodableColor(hex: "#3b4252"),
                backgroundTertiary: CodableColor(hex: "#434c5e"),
                text: CodableColor(hex: "#ffffff"),
                textSecondary: CodableColor(hex: "#eceff4"),
                textMuted: CodableColor(hex: "#c9d0dd"),
                accent: CodableColor(hex: "#88c0d0"),
                accentHover: CodableColor(hex: "#a3dce8"),
                gitAdded: CodableColor(hex: "#a3be8c"),
                gitModified: CodableColor(hex: "#ebcb8b"),
                gitDeleted: CodableColor(hex: "#d87684"),
                gitRenamed: CodableColor(hex: "#88c0d0"),
                gitConflict: CodableColor(hex: "#d5a1c3"),
                gitUntracked: CodableColor(hex: "#c9d0dd"),
                branchLocal: CodableColor(hex: "#a3be8c"),
                branchRemote: CodableColor(hex: "#88c0d0"),
                branchCurrent: CodableColor(hex: "#ebcb8b"),
                graphLine1: CodableColor(hex: "#88c0d0"),
                graphLine2: CodableColor(hex: "#a3be8c"),
                graphLine3: CodableColor(hex: "#ebcb8b"),
                graphLine4: CodableColor(hex: "#d5a1c3"),
                graphLine5: CodableColor(hex: "#d87684"),
                success: CodableColor(hex: "#a3be8c"),
                warning: CodableColor(hex: "#ebcb8b"),
                error: CodableColor(hex: "#d87684"),
                info: CodableColor(hex: "#88c0d0")
            )
        ),
        ThemePalette(
            name: "One Dark Pro",
            description: "Atom's iconic theme with perfect readability - AAA",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#282c34"),
                backgroundSecondary: CodableColor(hex: "#21252b"),
                backgroundTertiary: CodableColor(hex: "#2c313a"),
                text: CodableColor(hex: "#ffffff"),
                textSecondary: CodableColor(hex: "#dcdfe4"),
                textMuted: CodableColor(hex: "#abb2bf"),
                accent: CodableColor(hex: "#61afef"),
                accentHover: CodableColor(hex: "#84c0ff"),
                gitAdded: CodableColor(hex: "#98c379"),
                gitModified: CodableColor(hex: "#e5c07b"),
                gitDeleted: CodableColor(hex: "#e88388"),
                gitRenamed: CodableColor(hex: "#61afef"),
                gitConflict: CodableColor(hex: "#d399eb"),
                gitUntracked: CodableColor(hex: "#abb2bf"),
                branchLocal: CodableColor(hex: "#98c379"),
                branchRemote: CodableColor(hex: "#61afef"),
                branchCurrent: CodableColor(hex: "#e5c07b"),
                graphLine1: CodableColor(hex: "#61afef"),
                graphLine2: CodableColor(hex: "#98c379"),
                graphLine3: CodableColor(hex: "#e5c07b"),
                graphLine4: CodableColor(hex: "#d399eb"),
                graphLine5: CodableColor(hex: "#e88388"),
                success: CodableColor(hex: "#98c379"),
                warning: CodableColor(hex: "#e5c07b"),
                error: CodableColor(hex: "#e88388"),
                info: CodableColor(hex: "#61afef")
            )
        ),
        ThemePalette(
            name: "Monokai Pro",
            description: "Professional Monokai - Absolute maximum contrast AAA",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#2d2a2e"),
                backgroundSecondary: CodableColor(hex: "#221f22"),
                backgroundTertiary: CodableColor(hex: "#19181a"),
                text: CodableColor(hex: "#ffffff"),
                textSecondary: CodableColor(hex: "#fcfcfa"),
                textMuted: CodableColor(hex: "#c1c0c0"),
                accent: CodableColor(hex: "#ffd866"),
                accentHover: CodableColor(hex: "#ffe484"),
                gitAdded: CodableColor(hex: "#a9dc76"),
                gitModified: CodableColor(hex: "#ffd866"),
                gitDeleted: CodableColor(hex: "#ff6188"),
                gitRenamed: CodableColor(hex: "#78dce8"),
                gitConflict: CodableColor(hex: "#c5b0ff"),
                gitUntracked: CodableColor(hex: "#c1c0c0"),
                branchLocal: CodableColor(hex: "#a9dc76"),
                branchRemote: CodableColor(hex: "#78dce8"),
                branchCurrent: CodableColor(hex: "#ffd866"),
                graphLine1: CodableColor(hex: "#78dce8"),
                graphLine2: CodableColor(hex: "#a9dc76"),
                graphLine3: CodableColor(hex: "#ffd866"),
                graphLine4: CodableColor(hex: "#c5b0ff"),
                graphLine5: CodableColor(hex: "#ff6188"),
                success: CodableColor(hex: "#a9dc76"),
                warning: CodableColor(hex: "#ffd866"),
                error: CodableColor(hex: "#ff6188"),
                info: CodableColor(hex: "#78dce8")
            )
        ),
        ThemePalette(
            name: "Tokyo Night",
            description: "Clean, elegant dark theme - Maximum contrast AAA",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#1a1b26"),
                backgroundSecondary: CodableColor(hex: "#16161e"),
                backgroundTertiary: CodableColor(hex: "#24283b"),
                text: CodableColor(hex: "#ffffff"),
                textSecondary: CodableColor(hex: "#d5daf0"),
                textMuted: CodableColor(hex: "#a9b1d6"),
                accent: CodableColor(hex: "#7aa2f7"),
                accentHover: CodableColor(hex: "#9abcff"),
                gitAdded: CodableColor(hex: "#9ece6a"),
                gitModified: CodableColor(hex: "#e0af68"),
                gitDeleted: CodableColor(hex: "#f7768e"),
                gitRenamed: CodableColor(hex: "#7aa2f7"),
                gitConflict: CodableColor(hex: "#d0afff"),
                gitUntracked: CodableColor(hex: "#a9b1d6"),
                branchLocal: CodableColor(hex: "#9ece6a"),
                branchRemote: CodableColor(hex: "#7aa2f7"),
                branchCurrent: CodableColor(hex: "#e0af68"),
                graphLine1: CodableColor(hex: "#7aa2f7"),
                graphLine2: CodableColor(hex: "#9ece6a"),
                graphLine3: CodableColor(hex: "#e0af68"),
                graphLine4: CodableColor(hex: "#d0afff"),
                graphLine5: CodableColor(hex: "#f7768e"),
                success: CodableColor(hex: "#9ece6a"),
                warning: CodableColor(hex: "#e0af68"),
                error: CodableColor(hex: "#f7768e"),
                info: CodableColor(hex: "#7aa2f7")
            )
        ),
        ThemePalette(
            name: "Solarized Dark",
            description: "Precision dark colors - AAA contrast for comfort",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#002b36"),
                backgroundSecondary: CodableColor(hex: "#073642"),
                backgroundTertiary: CodableColor(hex: "#0e4c5a"),
                text: CodableColor(hex: "#fdf6e3"),
                textSecondary: CodableColor(hex: "#eee8d5"),
                textMuted: CodableColor(hex: "#93a1a1"),
                accent: CodableColor(hex: "#268bd2"),
                accentHover: CodableColor(hex: "#4da4de"),
                gitAdded: CodableColor(hex: "#859900"),
                gitModified: CodableColor(hex: "#b58900"),
                gitDeleted: CodableColor(hex: "#dc322f"),
                gitRenamed: CodableColor(hex: "#268bd2"),
                gitConflict: CodableColor(hex: "#d33682"),
                gitUntracked: CodableColor(hex: "#93a1a1"),
                branchLocal: CodableColor(hex: "#859900"),
                branchRemote: CodableColor(hex: "#268bd2"),
                branchCurrent: CodableColor(hex: "#b58900"),
                graphLine1: CodableColor(hex: "#268bd2"),
                graphLine2: CodableColor(hex: "#859900"),
                graphLine3: CodableColor(hex: "#b58900"),
                graphLine4: CodableColor(hex: "#6c71c4"),
                graphLine5: CodableColor(hex: "#dc322f"),
                success: CodableColor(hex: "#859900"),
                warning: CodableColor(hex: "#b58900"),
                error: CodableColor(hex: "#dc322f"),
                info: CodableColor(hex: "#268bd2")
            )
        )
    ]
}

struct CustomThemeEditor: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var customColors: CustomColorScheme
    @State private var selectedPalette: UUID?

    init() {
        let manager = ThemeManager.shared
        _customColors = State(initialValue: manager.customColors ?? .default)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 0) {
                // Left Panel - Palettes
                VStack(spacing: 0) {
                    Text("Presets")
                        .font(DesignTokens.Typography.headline)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.vertical, DesignTokens.Spacing.md)

                    Divider()

                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(ThemePalette.allPalettes) { palette in
                                PaletteCard(
                                    palette: palette,
                                    isSelected: selectedPalette == palette.id,
                                    onSelect: {
                                        selectedPalette = palette.id
                                        customColors = palette.colors
                                    }
                                )
                                .padding(.horizontal, DesignTokens.Spacing.md)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.md)
                    }
                }
                .frame(width: DesignTokens.Spacing.xxl * 8)
                .background(AppTheme.backgroundSecondary)

                Divider()

                // Right Panel - Color Customization
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Customize Theme")
                            .font(DesignTokens.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button("Reset to Default") {
                            customColors = .default
                            selectedPalette = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(DesignTokens.Spacing.lg)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                            ColorSection(title: "Background") {
                                CompactColorPicker(label: "Primary", color: $customColors.background)
                                CompactColorPicker(label: "Secondary", color: $customColors.backgroundSecondary)
                                CompactColorPicker(label: "Tertiary", color: $customColors.backgroundTertiary)
                            }

                            ColorSection(title: "Text") {
                                CompactColorPicker(label: "Primary", color: $customColors.text)
                                CompactColorPicker(label: "Secondary", color: $customColors.textSecondary)
                                CompactColorPicker(label: "Muted", color: $customColors.textMuted)
                            }

                            ColorSection(title: "Accent & UI") {
                                CompactColorPicker(label: "Accent", color: $customColors.accent)
                                CompactColorPicker(label: "Accent Hover", color: $customColors.accentHover)
                                CompactColorPicker(label: "Success", color: $customColors.success)
                                CompactColorPicker(label: "Error", color: $customColors.error)
                            }

                            ColorSection(title: "Git Status") {
                                CompactColorPicker(label: "Added", color: $customColors.gitAdded)
                                CompactColorPicker(label: "Modified", color: $customColors.gitModified)
                                CompactColorPicker(label: "Deleted", color: $customColors.gitDeleted)
                                CompactColorPicker(label: "Conflict", color: $customColors.gitConflict)
                            }

                            ColorSection(title: "Branches") {
                                CompactColorPicker(label: "Local", color: $customColors.branchLocal)
                                CompactColorPicker(label: "Remote", color: $customColors.branchRemote)
                                CompactColorPicker(label: "Current", color: $customColors.branchCurrent)
                            }

                            ColorSection(title: "Graph Lines") {
                                CompactColorPicker(label: "Line 1", color: $customColors.graphLine1)
                                CompactColorPicker(label: "Line 2", color: $customColors.graphLine2)
                                CompactColorPicker(label: "Line 3", color: $customColors.graphLine3)
                                CompactColorPicker(label: "Line 4", color: $customColors.graphLine4)
                                CompactColorPicker(label: "Line 5", color: $customColors.graphLine5)
                            }
                        }
                        .padding(DesignTokens.Spacing.xl)
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.background)

                    // Footer buttons
                    Divider()
                    HStack {
                        // Left side - Import/Export
                        DSButton("Import Theme...", variant: .secondary, size: .sm) {
                            themeManager.importThemeFromFile()
                        }

                        DSButton("Export Theme...", variant: .secondary, size: .sm) {
                            themeManager.exportThemeToFile()
                        }

                        Spacer()

                        DSButton("Cancel", variant: .secondary, size: .sm) {
                            ThemeEditorWindowController.shared.closeWindow()
                        }

                        DSButton("Apply Theme", variant: .primary, size: .sm) {
                            themeManager.setCustomColors(customColors)
                            ThemeEditorWindowController.shared.closeWindow()
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .background(AppTheme.backgroundSecondary)
                }
            }
        }
        .frame(width: 900, height: 650)
    }
}

// MARK: - Theme Editor Components

struct PaletteCard: View {
    let palette: ThemePalette
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // Title
                Text(palette.name)
                    .font(DesignTokens.Typography.headline)
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Color preview strip
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Rectangle()
                        .fill(palette.colors.background.color)
                    Rectangle()
                        .fill(palette.colors.accent.color)
                    Rectangle()
                        .fill(palette.colors.gitAdded.color)
                    Rectangle()
                        .fill(palette.colors.gitModified.color)
                    Rectangle()
                        .fill(palette.colors.gitDeleted.color)
                }
                .frame(height: DesignTokens.Size.buttonHeightSM)
                .cornerRadius(DesignTokens.CornerRadius.sm)

                // Description
                Text(palette.description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(isSelected ? AppTheme.accent.opacity(0.15) : AppTheme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .stroke(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ColorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                content()
            }
            .padding(DesignTokens.Spacing.md)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.lg)
        }
    }
}

struct CompactColorPicker: View {
    let label: String
    @Binding var color: CodableColor

    @State private var showingPopover = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Label
            Text(label)
                .font(DesignTokens.Typography.body)
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Color preview button
            Button(action: { showingPopover = true }) {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(color.color)
                    .frame(height: DesignTokens.Size.buttonHeightMD)
                    .aspectRatio(3, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .strokeBorder(AppTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ColorPicker("Select Color", selection: Binding(
                        get: { color.color },
                        set: { color = CodableColor($0) }
                    ))
                    .labelsHidden()

                    DSTextField(
                        placeholder: "Hex Color",
                        text: Binding(
                            get: { color.hexString },
                            set: { hex in
                                color = CodableColor(Color(hex: hex))
                            }
                        )
                    )

                    DSButton(variant: .primary, size: .sm) {
                        showingPopover = false
                    } label: {
                        Text("Done")
                    }
                }
                .padding(DesignTokens.Spacing.lg)
                .frame(minWidth: DesignTokens.Spacing.xxl * 8)
            }

            // Hex value (read-only display)
            Text(color.hexString)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Independent Theme Editor Window

@MainActor
class ThemeEditorWindowController {
    static let shared = ThemeEditorWindowController()
    private var window: NSWindow?

    private init() {}

    func showWindow() {
        // Si ya existe la ventana, la traemos al frente
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Crear nueva ventana independiente
        let contentView = CustomThemeEditor()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Customize Theme"
        window.minSize = NSSize(width: 800, height: 600)
        window.maxSize = NSSize(width: 1200, height: 900)
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)

        // Activar la app
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}

// MARK: - Theme Export/Import Data Structures

struct ThemeExportData: Codable {
    let name: String
    let version: String
    let colors: ColorScheme
}

enum ThemeError: Error, LocalizedError {
    case encodingFailed
    case invalidJSON
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode theme to JSON"
        case .invalidJSON:
            return "Invalid JSON format"
        case .decodingFailed:
            return "Failed to decode theme from JSON"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
