import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { regressionBaseline } from './regression-baseline.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-theme-controls-'));
try {
  const source = await fs.readFile(path.join(root, 'GitMac/UI/Theme/ThemeManager.swift'), 'utf8');
  const core = source.split('// MARK: - Theme Settings View')[0];
  const palettes = 'struct ThemePalette: Identifiable {' + source.split('struct ThemePalette: Identifiable {')[1]?.split('struct CustomThemeEditor: View')[0];
  const exports = source.split('// MARK: - Theme Export/Import Data Structures')[1];
  if (!exports?.includes('themeDidChange') || !palettes.includes('Solarized Dark')) throw Error('Theme extraction boundary changed');
  const production = path.join(temporary, 'ActualThemeCore.swift');
  await fs.writeFile(production, core + '\n' + palettes + '\n' + exports);
  const appTheme = path.join(temporary, 'ActualAppTheme.swift');
  await fs.writeFile(appTheme, (await fs.readFile(path.join(root, 'GitMac/UI/Components/AppTheme.swift'), 'utf8'))
    .replaceAll('ThemeManager.shared', 'ThemeFixture.manager'));
  const buttons = [];
  for (const name of ['DSButton', 'DSIconButton']) {
    const file = `GitMac/UI/Components/Atoms/Buttons/${name}.swift`;
    const text = process.argv.includes('--previous-source-control')
      ? execFileSync('git', ['show', `${regressionBaseline}:${file}`], { cwd: root, encoding: 'utf8' })
      : await fs.readFile(path.join(root, file), 'utf8');
    // Expose existing private state/getters in a same-file test extension only.
    // No copy of button policy or body is substituted.
    const extensionCode = `\nextension ${name} {
      mutating func fixtureHover(_ value: Bool) { _isHovered = State(initialValue: value) }
      mutating func fixtureLoading(_ value: Bool) { _isLoading = State(initialValue: value) }
      var fixtureColors: (Color, Color) { (foregroundColor, backgroundColor) }
    }\n`;
    const destination = path.join(temporary, name + '.swift');
    await fs.writeFile(destination, text.split('// MARK: - Previews')[0] + extensionCode);
    buttons.push(destination);
  }
  const harness = String.raw`import Foundation
import SwiftUI
import AppKit
enum Logger { static func debug(_ message: @autoclosure () -> String) {} }
@MainActor enum ThemeFixture {
    static var instance: ThemeManager?
    static var manager: ThemeManager { guard let instance else { preconditionFailure("missing fixture") }; return instance }
}
@main struct ControlChecks {
    @MainActor static func main() throws {
        let suite = "GitMacControlFixture." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = ThemeManager(defaults: defaults)
        ThemeFixture.instance = manager
        var checks = 0, failures = 0
        func check(_ condition: Bool, _ label: String) {
            checks += 1; if !condition { failures += 1; print("FAIL " + label) }
        }
        // Independent sRGB contrast oracle, including alpha over the actual theme background.
        func painted(_ color: CodableColor, over backdrop: [Double]) -> [Double] {
            zip([color.red, color.green, color.blue], backdrop).map { $0 * color.alpha + $1 * (1 - color.alpha) }
        }
        func luminance(_ rgb: [Double]) -> Double {
            let linear = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        func ratio(_ foreground: Color, _ background: Color, on backdrop: CodableColor) -> Double {
            let bg = painted(CodableColor(background), over: [backdrop.red, backdrop.green, backdrop.blue])
            let fg = painted(CodableColor(foreground), over: bg)
            let a = luminance(fg), b = luminance(bg)
            return (max(a, b) + 0.05) / (min(a, b) + 0.05)
        }
        let variants: [DSButtonVariant] = [.primary, .secondary, .danger, .ghost, .outline, .link]
        let sizes: [DSButtonSize] = [.sm, .md, .lg]
        for palette in ThemePalette.allPalettes {
            manager.setCustomColors(palette.colors)
            for variant in variants {
                for size in sizes {
                    for hovered in [false, true] {
                        var button = DSButton(variant: variant, size: size, action: { () async in }) { Text("Save changes") }
                        var icon = DSIconButton(iconName: "star", variant: variant, size: size, action: { () async in })
                        button.fixtureHover(hovered); icon.fixtureHover(hovered)
                        let a = button.fixtureColors, b = icon.fixtureColors
                        check(ratio(a.0, a.1, on: palette.colors.background) >= 4.5,
                              "\(palette.name)/\(variant)/\(size)/hover=\(hovered): button text contrast")
                        check(ratio(b.0, b.1, on: palette.colors.background) >= 4.5,
                              "\(palette.name)/\(variant)/\(size)/hover=\(hovered): icon contrast")
                    }
                    let disabled = DSButton(variant: variant, size: size, isDisabled: true, action: { () async in }) { Text("Save changes") }
                    let disabledIcon = DSIconButton(iconName: "star", variant: variant, size: size, isDisabled: true, action: { () async in })
                    check(CodableColor(disabled.fixtureColors.0) == CodableColor(AppTheme.textMuted), "disabled button uses muted semantic role")
                    check(CodableColor(disabledIcon.fixtureColors.0) == CodableColor(AppTheme.textMuted), "disabled icon uses muted semantic role")
                }
            }
            for size in sizes {
                let normal = DSButton(variant: .primary, size: size, action: { () async in }) { Text("Save changes") }
                var loading = normal; loading.fixtureLoading(true)
                let normalSize = NSHostingView(rootView: normal).fittingSize
                let loadingSize = NSHostingView(rootView: loading).fittingSize
                check(abs(normalSize.width - loadingSize.width) < 0.5 && abs(normalSize.height - loadingSize.height) < 0.5,
                      "\(palette.name)/\(size): loading preserves button size")
            }
        }
        print("THEME_CONTROL_CHECKS: \(checks) checks, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
`;
  const main = path.join(temporary, 'ControlChecks.swift'); await fs.writeFile(main, harness);
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const binary = path.join(temporary, 'controls');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    production, appTheme, path.join(root, 'GitMac/UI/Theme/DesignTokens.swift'), ...buttons, main, '-o', binary],
    { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 60000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
