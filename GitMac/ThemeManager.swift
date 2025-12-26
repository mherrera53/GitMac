import SwiftUI
import Combine

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
    
    init() {
        loadSavedTheme()
        applyTheme()
    }
    
    // MARK: - Theme Application
    
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        saveTheme()
        applyTheme()
        
        // Notify all windows
        NotificationCenter.default.post(name: .themeDidChange, object: theme)
    }
    
    func applyTheme() {
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
    }
    
    // MARK: - Custom Colors
    
    func setCustomColors(_ colors: CustomColorScheme) {
        customColors = colors
        currentTheme = .custom
        saveCustomColors()
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
    }
    
    private func loadSavedTheme() {
        if let themeRaw = defaults.string(forKey: themeKey),
           let theme = Theme(rawValue: themeRaw) {
            currentTheme = theme
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
        self.background = custom.background
        self.backgroundSecondary = custom.backgroundSecondary
        self.backgroundTertiary = custom.backgroundTertiary
        self.text = custom.text
        self.textSecondary = custom.textSecondary
        self.textMuted = custom.textMuted
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
    }

    init(background: CodableColor, backgroundSecondary: CodableColor, backgroundTertiary: CodableColor,
         text: CodableColor, textSecondary: CodableColor, textMuted: CodableColor,
         accent: CodableColor, accentHover: CodableColor,
         gitAdded: CodableColor, gitModified: CodableColor, gitDeleted: CodableColor,
         gitRenamed: CodableColor, gitConflict: CodableColor, gitUntracked: CodableColor,
         branchLocal: CodableColor, branchRemote: CodableColor, branchCurrent: CodableColor,
         graphLine1: CodableColor, graphLine2: CodableColor, graphLine3: CodableColor,
         graphLine4: CodableColor, graphLine5: CodableColor,
         success: CodableColor, warning: CodableColor, error: CodableColor, info: CodableColor) {
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
        info: CodableColor(hex: "#2196F3")
    )
    
    // Dark Theme
    static let dark = ColorScheme(
        background: CodableColor(hex: "#1E1E1E"),
        backgroundSecondary: CodableColor(hex: "#252526"),
        backgroundTertiary: CodableColor(hex: "#2D2D30"),
        text: CodableColor(hex: "#CCCCCC"),
        textSecondary: CodableColor(hex: "#999999"),
        textMuted: CodableColor(hex: "#666666"),
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
        info: CodableColor(hex: "#569CD6")
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
        info: CodableColor(hex: "#2196F3")
    )
}

// MARK: - Custom Color Scheme (User-editable)

struct CustomColorScheme: Codable {
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

struct CodableColor: Codable {
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
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showCustomEditor = false
    
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
                    showCustomEditor = true
                } label: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.purple)
                        
                        Text("Customize Colors...")
                        
                        Spacer()
                        
                        if themeManager.currentTheme == .custom {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.currentTheme == .custom ? Color.purple : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Preview
            ThemePreview()
        }
        .padding()
        .sheet(isPresented: $showCustomEditor) {
            CustomThemeEditor()
        }
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
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        switch theme {
        case .system: return .gray
        case .light: return .orange
        case .dark: return .indigo
        case .custom: return .purple
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
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
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
                .foregroundColor(.secondary)
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
        ThemePalette(
            name: "GitHub Dark",
            description: "Classic GitHub dark theme",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#0d1117"),
                backgroundSecondary: CodableColor(hex: "#161b22"),
                backgroundTertiary: CodableColor(hex: "#21262d"),
                text: CodableColor(hex: "#c9d1d9"),
                textSecondary: CodableColor(hex: "#8b949e"),
                textMuted: CodableColor(hex: "#6e7681"),
                accent: CodableColor(hex: "#58a6ff"),
                accentHover: CodableColor(hex: "#1f6feb"),
                gitAdded: CodableColor(hex: "#3fb950"),
                gitModified: CodableColor(hex: "#d29922"),
                gitDeleted: CodableColor(hex: "#f85149"),
                gitRenamed: CodableColor(hex: "#58a6ff"),
                gitConflict: CodableColor(hex: "#da3633"),
                gitUntracked: CodableColor(hex: "#8b949e"),
                branchLocal: CodableColor(hex: "#3fb950"),
                branchRemote: CodableColor(hex: "#58a6ff"),
                branchCurrent: CodableColor(hex: "#d29922"),
                graphLine1: CodableColor(hex: "#58a6ff"),
                graphLine2: CodableColor(hex: "#3fb950"),
                graphLine3: CodableColor(hex: "#d29922"),
                graphLine4: CodableColor(hex: "#bc8cff"),
                graphLine5: CodableColor(hex: "#f85149"),
                success: CodableColor(hex: "#3fb950"),
                warning: CodableColor(hex: "#d29922"),
                error: CodableColor(hex: "#f85149"),
                info: CodableColor(hex: "#58a6ff")
            )
        ),
        ThemePalette(
            name: "Dracula",
            description: "Popular dark theme with vibrant colors",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#282a36"),
                backgroundSecondary: CodableColor(hex: "#21222c"),
                backgroundTertiary: CodableColor(hex: "#191a21"),
                text: CodableColor(hex: "#f8f8f2"),
                textSecondary: CodableColor(hex: "#6272a4"),
                textMuted: CodableColor(hex: "#44475a"),
                accent: CodableColor(hex: "#bd93f9"),
                accentHover: CodableColor(hex: "#9580d6"),
                gitAdded: CodableColor(hex: "#50fa7b"),
                gitModified: CodableColor(hex: "#f1fa8c"),
                gitDeleted: CodableColor(hex: "#ff5555"),
                gitRenamed: CodableColor(hex: "#8be9fd"),
                gitConflict: CodableColor(hex: "#ff79c6"),
                gitUntracked: CodableColor(hex: "#6272a4"),
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
                error: CodableColor(hex: "#ff5555"),
                info: CodableColor(hex: "#8be9fd")
            )
        ),
        ThemePalette(
            name: "Nord",
            description: "Arctic, north-bluish color palette",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#2e3440"),
                backgroundSecondary: CodableColor(hex: "#3b4252"),
                backgroundTertiary: CodableColor(hex: "#434c5e"),
                text: CodableColor(hex: "#eceff4"),
                textSecondary: CodableColor(hex: "#d8dee9"),
                textMuted: CodableColor(hex: "#4c566a"),
                accent: CodableColor(hex: "#88c0d0"),
                accentHover: CodableColor(hex: "#5e81ac"),
                gitAdded: CodableColor(hex: "#a3be8c"),
                gitModified: CodableColor(hex: "#ebcb8b"),
                gitDeleted: CodableColor(hex: "#bf616a"),
                gitRenamed: CodableColor(hex: "#81a1c1"),
                gitConflict: CodableColor(hex: "#b48ead"),
                gitUntracked: CodableColor(hex: "#4c566a"),
                branchLocal: CodableColor(hex: "#a3be8c"),
                branchRemote: CodableColor(hex: "#81a1c1"),
                branchCurrent: CodableColor(hex: "#ebcb8b"),
                graphLine1: CodableColor(hex: "#88c0d0"),
                graphLine2: CodableColor(hex: "#a3be8c"),
                graphLine3: CodableColor(hex: "#ebcb8b"),
                graphLine4: CodableColor(hex: "#b48ead"),
                graphLine5: CodableColor(hex: "#bf616a"),
                success: CodableColor(hex: "#a3be8c"),
                warning: CodableColor(hex: "#ebcb8b"),
                error: CodableColor(hex: "#bf616a"),
                info: CodableColor(hex: "#88c0d0")
            )
        ),
        ThemePalette(
            name: "One Dark Pro",
            description: "Atom's iconic dark theme",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#282c34"),
                backgroundSecondary: CodableColor(hex: "#21252b"),
                backgroundTertiary: CodableColor(hex: "#2c313a"),
                text: CodableColor(hex: "#abb2bf"),
                textSecondary: CodableColor(hex: "#5c6370"),
                textMuted: CodableColor(hex: "#4b5263"),
                accent: CodableColor(hex: "#61afef"),
                accentHover: CodableColor(hex: "#528bff"),
                gitAdded: CodableColor(hex: "#98c379"),
                gitModified: CodableColor(hex: "#e5c07b"),
                gitDeleted: CodableColor(hex: "#e06c75"),
                gitRenamed: CodableColor(hex: "#61afef"),
                gitConflict: CodableColor(hex: "#c678dd"),
                gitUntracked: CodableColor(hex: "#5c6370"),
                branchLocal: CodableColor(hex: "#98c379"),
                branchRemote: CodableColor(hex: "#61afef"),
                branchCurrent: CodableColor(hex: "#e5c07b"),
                graphLine1: CodableColor(hex: "#61afef"),
                graphLine2: CodableColor(hex: "#98c379"),
                graphLine3: CodableColor(hex: "#e5c07b"),
                graphLine4: CodableColor(hex: "#c678dd"),
                graphLine5: CodableColor(hex: "#e06c75"),
                success: CodableColor(hex: "#98c379"),
                warning: CodableColor(hex: "#e5c07b"),
                error: CodableColor(hex: "#e06c75"),
                info: CodableColor(hex: "#61afef")
            )
        ),
        ThemePalette(
            name: "Monokai Pro",
            description: "Professional Monokai variant",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#2d2a2e"),
                backgroundSecondary: CodableColor(hex: "#221f22"),
                backgroundTertiary: CodableColor(hex: "#19181a"),
                text: CodableColor(hex: "#fcfcfa"),
                textSecondary: CodableColor(hex: "#939293"),
                textMuted: CodableColor(hex: "#5b595c"),
                accent: CodableColor(hex: "#ffd866"),
                accentHover: CodableColor(hex: "#ffcc66"),
                gitAdded: CodableColor(hex: "#a9dc76"),
                gitModified: CodableColor(hex: "#ffd866"),
                gitDeleted: CodableColor(hex: "#ff6188"),
                gitRenamed: CodableColor(hex: "#78dce8"),
                gitConflict: CodableColor(hex: "#ab9df2"),
                gitUntracked: CodableColor(hex: "#939293"),
                branchLocal: CodableColor(hex: "#a9dc76"),
                branchRemote: CodableColor(hex: "#78dce8"),
                branchCurrent: CodableColor(hex: "#ffd866"),
                graphLine1: CodableColor(hex: "#78dce8"),
                graphLine2: CodableColor(hex: "#a9dc76"),
                graphLine3: CodableColor(hex: "#ffd866"),
                graphLine4: CodableColor(hex: "#ab9df2"),
                graphLine5: CodableColor(hex: "#ff6188"),
                success: CodableColor(hex: "#a9dc76"),
                warning: CodableColor(hex: "#ffd866"),
                error: CodableColor(hex: "#ff6188"),
                info: CodableColor(hex: "#78dce8")
            )
        ),
        ThemePalette(
            name: "Tokyo Night",
            description: "Clean, elegant dark theme",
            colors: CustomColorScheme(
                background: CodableColor(hex: "#1a1b26"),
                backgroundSecondary: CodableColor(hex: "#16161e"),
                backgroundTertiary: CodableColor(hex: "#24283b"),
                text: CodableColor(hex: "#c0caf5"),
                textSecondary: CodableColor(hex: "#9aa5ce"),
                textMuted: CodableColor(hex: "#565f89"),
                accent: CodableColor(hex: "#7aa2f7"),
                accentHover: CodableColor(hex: "#2ac3de"),
                gitAdded: CodableColor(hex: "#9ece6a"),
                gitModified: CodableColor(hex: "#e0af68"),
                gitDeleted: CodableColor(hex: "#f7768e"),
                gitRenamed: CodableColor(hex: "#7aa2f7"),
                gitConflict: CodableColor(hex: "#bb9af7"),
                gitUntracked: CodableColor(hex: "#565f89"),
                branchLocal: CodableColor(hex: "#9ece6a"),
                branchRemote: CodableColor(hex: "#7aa2f7"),
                branchCurrent: CodableColor(hex: "#e0af68"),
                graphLine1: CodableColor(hex: "#7aa2f7"),
                graphLine2: CodableColor(hex: "#9ece6a"),
                graphLine3: CodableColor(hex: "#e0af68"),
                graphLine4: CodableColor(hex: "#bb9af7"),
                graphLine5: CodableColor(hex: "#f7768e"),
                success: CodableColor(hex: "#9ece6a"),
                warning: CodableColor(hex: "#e0af68"),
                error: CodableColor(hex: "#f7768e"),
                info: CodableColor(hex: "#7aa2f7")
            )
        )
    ]
}

struct CustomThemeEditor: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var customColors: CustomColorScheme
    @State private var selectedPalette: UUID?
    @Environment(\.dismiss) private var dismiss

    init() {
        let manager = ThemeManager.shared
        _customColors = State(initialValue: manager.customColors ?? .default)
    }

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Left Panel - Palettes
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Predefined Palettes")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        ForEach(ThemePalette.allPalettes) { palette in
                            PaletteCard(
                                palette: palette,
                                isSelected: selectedPalette == palette.id,
                                onSelect: {
                                    selectedPalette = palette.id
                                    customColors = palette.colors
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .frame(width: 280)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Right Panel - Color Customization
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Customize Colors")
                            .font(.headline)
                            .foregroundColor(.secondary)

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

                        Button("Reset to Default") {
                            customColors = .default
                            selectedPalette = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Custom Theme")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        themeManager.setCustomColors(customColors)
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 900, height: 700)
    }
}

// MARK: - Theme Editor Components

struct PaletteCard: View {
    let palette: ThemePalette
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(palette.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(palette.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                    }
                }

                // Color preview strip
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(palette.colors.background.color)
                        .frame(height: 24)
                    Rectangle()
                        .fill(palette.colors.accent.color)
                        .frame(height: 24)
                    Rectangle()
                        .fill(palette.colors.gitAdded.color)
                        .frame(height: 24)
                    Rectangle()
                        .fill(palette.colors.gitModified.color)
                        .frame(height: 24)
                    Rectangle()
                        .fill(palette.colors.gitDeleted.color)
                        .frame(height: 24)
                }
                .cornerRadius(4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ColorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 6) {
                content()
            }
        }
    }
}

struct CompactColorPicker: View {
    let label: String
    @Binding var color: CodableColor

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 100, alignment: .leading)
                .foregroundColor(.primary)

            ColorPicker("", selection: Binding(
                get: { color.color },
                set: { color = CodableColor($0) }
            ))
            .labelsHidden()

            Text(color.hexString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
