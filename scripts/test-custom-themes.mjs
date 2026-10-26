import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-custom-theme-'));
try {
  const file = 'GitMac/UI/Theme/ThemeManager.swift';
  let source = process.argv.includes('--previous-source-control')
    ? execFileSync('git', ['show', `${regressionBaseline}:${file}`], { cwd: root, encoding: 'utf8' })
    : await fs.readFile(path.join(root, file), 'utf8');
  if (process.argv.includes('--previous-source-control')) {
    // Constructor injection seam only. Original theme behavior stays unchanged.
    source = source.replace('private let defaults = UserDefaults.standard', 'private let defaults: UserDefaults')
      .replace('private init() {\n        loadSavedTheme()', 'init(defaults: UserDefaults = .standard) {\n        self.defaults = defaults\n        loadSavedTheme()');
  }
  const core = source.split('// MARK: - Theme Settings View')[0];
  const palettes = 'struct ThemePalette: Identifiable {' + source.split('struct ThemePalette: Identifiable {')[1]?.split('struct CustomThemeEditor: View')[0];
  const exports = source.split('// MARK: - Theme Export/Import Data Structures')[1];
  if (!core.includes('class ThemeManager') || !palettes.includes('Solarized Dark') || !exports?.includes('themeDidChange')) throw Error('Production extraction boundary changed');
  const production = path.join(temporary, 'ActualThemeCore.swift');
  await fs.writeFile(production, core + '\n' + palettes + '\n' + exports);
  const appTheme = path.join(temporary, 'ActualAppTheme.swift');
  // Dependency seam only: all getters remain production code, using the real
  // ThemeManager backed by this test's isolated UserDefaults suite.
  const appThemeSource = process.argv.includes('--previous-app-theme-control')
    ? execFileSync('git', ['show', `${regressionBaseline}:GitMac/UI/Components/AppTheme.swift`], { cwd: root, encoding: 'utf8' })
    : await fs.readFile(path.join(root, 'GitMac/UI/Components/AppTheme.swift'), 'utf8');
  await fs.writeFile(appTheme, appThemeSource.replaceAll('ThemeManager.shared', 'ThemeFixture.manager'));
  const contentView = process.argv.includes('--previous-toolbar-control')
    ? execFileSync('git', ['show', `${regressionBaseline}:GitMac/App/ContentView.swift`], { cwd: root, encoding: 'utf8' })
    : await fs.readFile(path.join(root, 'GitMac/App/ContentView.swift'), 'utf8');
  const toolbarStart = contentView.indexOf('private var toolbarColorScheme: SwiftUI.ColorScheme?');
  const toolbarEnd = contentView.indexOf('\n    private var toolbarConfigurationMenu', toolbarStart);
  if (toolbarStart < 0 || toolbarEnd < 0) throw Error('Actual toolbar theme boundary changed');
  const toolbar = path.join(temporary, 'ActualToolbarTheme.swift');
  await fs.writeFile(toolbar, 'import SwiftUI\n@MainActor struct ActualToolbarTheme {\n'
    + contentView.slice(toolbarStart, toolbarEnd).replace('private var', 'var').replaceAll('ThemeManager.shared', 'ThemeFixture.manager') + '\n}\n');
  const harness = String.raw`import Foundation
import SwiftUI
import AppKit

@MainActor enum ThemeFixture {
    static var instance: ThemeManager?
    static var manager: ThemeManager {
        guard let instance else { preconditionFailure("Theme fixture must be configured before reading tokens") }
        return instance
    }
}

@main struct ThemeChecks {
    @MainActor static func main() throws {
        let suite = "GitMacThemeFixture." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = ThemeManager(defaults: defaults)
        ThemeFixture.instance = manager
        var checks = 0, failures = 0
        func check(_ condition: Bool, _ label: String) {
            checks += 1; if !condition { failures += 1 }
            print("\(condition ? "PASS" : "FAIL") \(label)")
        }
        for palette in ThemePalette.allPalettes {
            manager.setCustomColors(palette.colors)
            check(manager.currentTheme == .custom && manager.colors.background == palette.colors.background,
                  palette.name + ": custom background applied")
            check(manager.colors.text == palette.colors.text && manager.colors.textSecondary == palette.colors.textSecondary
                    && manager.colors.textMuted == palette.colors.textMuted, palette.name + ": chosen text colors preserved")
            let expected: NSAppearance.Name = palette.colors.background.isLight ? .aqua : .darkAqua
            check(manager.appearance?.name == expected, palette.name + ": native controls match custom background")
            let expectedToolbar: SwiftUI.ColorScheme = ["GitHub Light", "Solarized Light"].contains(palette.name) ? .light : .dark
            check(ActualToolbarTheme().toolbarColorScheme == expectedToolbar, palette.name + ": main toolbar respects custom appearance")
            func same(_ rendered: Color, _ expected: CodableColor) -> Bool {
                let actual = CodableColor(rendered)
                return abs(actual.red - expected.red) < 0.001 && abs(actual.green - expected.green) < 0.001
                    && abs(actual.blue - expected.blue) < 0.001
            }
            check(same(AppTheme.background, palette.colors.background) && same(AppTheme.backgroundSecondary, palette.colors.backgroundSecondary)
                    && same(AppTheme.backgroundTertiary, palette.colors.backgroundTertiary), palette.name + ": shared background tokens render actual palette")
            check(same(AppTheme.textPrimary, palette.colors.text) && same(AppTheme.textSecondary, palette.colors.textSecondary)
                    && same(AppTheme.textMuted, palette.colors.textMuted), palette.name + ": shared text tokens render actual palette")
            check(same(AppTheme.accent, palette.colors.accent) && same(AppTheme.accentHover, palette.colors.accentHover),
                  palette.name + ": shared accent tokens render actual palette")
            check(same(AppTheme.gitRenamed, palette.colors.gitRenamed) && same(AppTheme.gitUntracked, palette.colors.gitUntracked),
                  palette.name + ": rename and untracked use their own semantic colors")
            let foreground = CodableColor(AppTheme.buttonTextOnColor).luminance
            let background = palette.colors.accent.luminance
            check((max(foreground, background) + 0.05) / (min(foreground, background) + 0.05) >= 4.5,
                  palette.name + ": accent button text has sufficient contrast")
        }
        var selected = ThemePalette.allPalettes[0].colors
        selected.text = CodableColor(hex: "#123456")
        selected.textSecondary = CodableColor(hex: "#345678")
        selected.textMuted = CodableColor(hex: "#567890")
        selected.accent = CodableColor(hex: "#A04070")
        manager.setCustomColors(selected)
        let restored = ThemeManager(defaults: defaults)
        check(restored.currentTheme == .custom && restored.customColors == selected, "custom colors and selection restored from isolated persistent store")
        check(restored.colors.text == selected.text && restored.colors.accent == selected.accent, "restored renderer respects selected colors")
        let json = try manager.exportThemeToJSON()
        manager.setTheme(.dark)
        try manager.importThemeFromJSON(json)
        check(manager.currentTheme == .custom && manager.colors.text == selected.text && manager.colors.accent == selected.accent,
              "export/import preserves custom colors")
        var data = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        var colors = data["colors"] as! [String: Any]
        colors["diffAddition"] = ["red": 0.2, "green": 0.4, "blue": 0.6, "alpha": 1.0]
        data["colors"] = colors
        try manager.importThemeFromJSON(String(decoding: JSONSerialization.data(withJSONObject: data), as: UTF8.self))
        check(manager.colors.diffAddition == CodableColor(hex: "#336699"), "import/export retains explicit diff colors")
        let beforeInvalid = try manager.exportThemeToJSON()
        do { try manager.importThemeFromJSON("{invalid"); check(false, "invalid import rejected") }
        catch { check(try manager.exportThemeToJSON() == beforeInvalid, "invalid import leaves active theme unchanged") }
        manager.resetToDefault()
        check(manager.currentTheme == .system && manager.customColors == nil && defaults.data(forKey: "customColors") == nil,
              "reset clears persisted custom colors")
        let resetRestored = ThemeManager(defaults: defaults)
        check(resetRestored.currentTheme == .system && resetRestored.customColors == nil,
              "reset survives relaunch without resurrecting old palette")
        check(CodableColor(AppTheme.background) == CodableColor(Color(nsColor: .windowBackgroundColor))
                && CodableColor(AppTheme.textPrimary) == CodableColor(Color(nsColor: .labelColor)),
              "system mode restores native semantic colors")
        manager.setTheme(.light)
        check(ActualToolbarTheme().toolbarColorScheme == .light, "main toolbar honors explicit light mode")
        manager.setTheme(.dark)
        check(ActualToolbarTheme().toolbarColorScheme == .dark, "main toolbar honors explicit dark mode")
        manager.setTheme(.system)
        check(ActualToolbarTheme().toolbarColorScheme == nil, "main toolbar delegates system appearance to macOS")
        print("CUSTOM_THEME_CHECKS: \(checks) checks, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
`;
  const main = path.join(temporary, 'ThemeChecks.swift'); await fs.writeFile(main, harness);
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const binary = path.join(temporary, 'theme-check-' + Date.now());
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    production, appTheme, toolbar, main, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
