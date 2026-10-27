import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const negative = process.argv.includes('--transparent-control');
const output = path.join(root, 'build', negative ? 'ToastVisualValidation-negative' : 'ToastVisualValidation');
await fs.mkdir(output, { recursive: true });
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-toast-tests-'));
try {
  const theme = await fs.readFile(path.join(root, 'GitMac/UI/Theme/ThemeManager.swift'), 'utf8');
  const core = theme.split('// MARK: - Theme Settings View')[0];
  const palettes = 'struct ThemePalette: Identifiable {' + theme.split('struct ThemePalette: Identifiable {')[1]?.split('struct CustomThemeEditor: View')[0];
  const exports = theme.split('// MARK: - Theme Export/Import Data Structures')[1];
  if (!exports || !palettes.includes('Solarized Dark')) throw Error('Theme boundary changed');
  await fs.writeFile(path.join(temporary, 'Theme.swift'), core + '\n' + palettes + '\n' + exports);
  await fs.writeFile(path.join(temporary, 'AppTheme.swift'), (await fs.readFile(path.join(root, 'GitMac/UI/Components/AppTheme.swift'), 'utf8')).replaceAll('ThemeManager.shared', 'ThemeFixture.manager'));
  let notifications = await fs.readFile(path.join(root, 'GitMac/Core/Services/NotificationManager.swift'), 'utf8');
  if (negative) {
    const boundary = '.background(ToastAppearance.surface)';
    if (notifications.split(boundary).length !== 2) throw Error('Toast mutation boundary changed');
    notifications = notifications.replace(boundary, '.background(Color.clear)');
  }
  await fs.writeFile(path.join(temporary, 'Notifications.swift'), notifications + '\nextension NotificationManager { var fixtureScheduledDismissals: Int { dismissalTasks.count } }\n');
  const legacy = (await fs.readFile(path.join(root, 'GitMac/UI/Components/ContextMenus.swift'), 'utf8')).split('// MARK: - Toast Notification')[1];
  if (!legacy?.includes('struct ToastView: View')) throw Error('Legacy toast boundary changed');
  await fs.writeFile(path.join(temporary, 'Legacy.swift'), 'import SwiftUI\nimport AppKit\n' + legacy);
  await fs.writeFile(path.join(temporary, 'Checks.swift'), String.raw`import SwiftUI
import AppKit
import Foundation
enum Logger { static func debug(_ message: @autoclosure () -> String) {} }
@MainActor enum ThemeFixture {
    static var instance: ThemeManager?
    static var manager: ThemeManager { instance! }
}
struct NotificationMessage { let message: String; let type: NotificationType; let detail: String? }
extension Notification.Name { static let showNotification = Notification.Name("GitMacToastFixtureOnly") }
@main struct Checks {
 @MainActor static func main() async throws {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    let suite = "GitMacToastFixture." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let theme = ThemeManager(defaults: defaults)
    ThemeFixture.instance = theme
    var checks = 0, failures = 0
    func check(_ condition: Bool, _ label: String) {
        checks += 1
        if !condition { failures += 1; print("FAIL " + label) }
    }
    func luminance(_ rgb: [Double]) -> Double {
        let linear = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
    func ratio(_ fg: Color, _ bg: Color) -> Double {
        let b = CodableColor(bg), f = CodableColor(fg)
        let rgb = zip([f.red, f.green, f.blue], [b.red, b.green, b.blue]).map { $0 * f.alpha + $1 * (1 - f.alpha) }
        let a = luminance(rgb), c = luminance([b.red, b.green, b.blue])
        return (max(a, c) + 0.05) / (min(a, c) + 0.05)
    }
    func render<V: View>(_ content: V, backdrop: Color) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: content.environment(theme).frame(width: 460).padding(12).background(backdrop))
        renderer.scale = 1
        let image = try renderer.nsImage.unwrap("SwiftUI snapshot unavailable")
        var rect = CGRect(origin: .zero, size: image.size)
        let cg = try image.cgImage(forProposedRect: &rect, context: nil, hints: nil).unwrap("Snapshot has no pixels")
        return NSBitmapImageRep(cgImage: cg)
    }
    func sameSurface<V: View>(_ content: V, label: String) throws -> NSBitmapImageRep {
        let a = try render(content, backdrop: .red), b = try render(content, backdrop: .blue)
        let p = try a.colorAt(x: 18, y: a.pixelsHigh / 2).unwrap("Missing pixel").usingColorSpace(.sRGB).unwrap("Missing sRGB pixel")
        let q = try b.colorAt(x: 18, y: b.pixelsHigh / 2).unwrap("Missing pixel").usingColorSpace(.sRGB).unwrap("Missing sRGB pixel")
        check(abs(p.redComponent-q.redComponent)<0.01 && abs(p.blueComponent-q.blueComponent)<0.01 && abs(p.greenComponent-q.greenComponent)<0.01, label + ": toast hides content behind it")
        return a
    }
    let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let types: [NotificationType] = [.success, .error, .warning, .info]
    for (index, palette) in ThemePalette.allPalettes.enumerated() {
        theme.setCustomColors(palette.colors)
        let surface = ToastAppearance.surface
        check(abs(CodableColor(surface).alpha - 1)<0.001, palette.name + ": opaque surface")
        check(ratio(ToastAppearance.text, surface)>=4.5, palette.name + ": title contrast")
        check(ratio(ToastAppearance.secondaryText, surface)>=4.5, palette.name + ": detail contrast")
        for (kind, type) in types.enumerated() {
            check(ratio(ToastAppearance.status(type), surface)>=4.5, palette.name + ": status contrast")
            let notification = ToastNotification(message: "Could not publish the changes in this repository\nYour local work is preserved. Review the remote branch and try again when you are ready.", type: type, duration: 6, actionTitle: kind == 1 ? "Review and retry" : nil, actionHint: "Review the failed operation", action: kind == 1 ? {} : nil)
            let image = try sameSurface(ToastNotificationView(notification: notification, onDismiss: {}), label: palette.name + "/\(kind)")
            let file = output.appendingPathComponent("toast-\(index)-\(kind).png")
            try image.representation(using: .png, properties: [:]).unwrap("PNG encoding failed").write(to: file)
            let legacyType: ToastView.ToastType = kind == 0 ? .success : kind == 1 ? .error : kind == 2 ? .warning : .info
            _ = try sameSurface(ToastView(message: "Changes saved locally", icon: type.icon, type: legacyType, onDismiss: {}), label: palette.name + "/legacy/\(kind)")
        }
    }
    var alphaPalette = ThemePalette.allPalettes[0].colors
    alphaPalette.background = CodableColor(red: 0, green: 0, blue: 0, alpha: 0.1)
    alphaPalette.backgroundSecondary = CodableColor(red: 1, green: 1, blue: 1, alpha: 0.1)
    alphaPalette.text = CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.1)
    theme.setCustomColors(alphaPalette)
    check(CodableColor(ToastAppearance.surface).alpha == 1, "translucent custom palette still has an opaque toast")
    check(ratio(ToastAppearance.text, ToastAppearance.surface)>=4.5, "low-contrast custom title corrected locally")
    _ = try sameSurface(ToastNotificationView(notification: .init(message: "Custom theme test", type: .info, duration: 5), onDismiss: {}), label: "custom alpha")
    let short = try render(ToastNotificationView(notification: .init(message: "Saved", type: .info, duration: 5), onDismiss: {}), backdrop: .red)
    let long = try render(ToastNotificationView(notification: .init(message: String(repeating: "A long recovery message needs room to be readable. ", count: 6) + "\n" + String(repeating: "Keep your work and review the operation. ", count: 5), type: .error, duration: 5), onDismiss: {}), backdrop: .red)
    check(long.pixelsHigh > short.pixelsHigh, "long title/detail wrap instead of sharing one truncated row")
    func settle() async { try? await Task.sleep(nanoseconds: 10_000_000) }
    let manager = NotificationManager(defaults: defaults, observeNotifications: false)
    manager.recordAction("Read status")
    manager.error("No retry available")
    await settle()
    check(manager.notifications.last?.hasAction == false, "no dead retry button when no retry handler exists")
    manager.dismissAll()
    var first = 0, second = 0
    let originalRetry: () async -> Void = { first += 1 }
    manager.recordAction("Original action", retry: originalRetry)
    manager.error("An unrelated error")
    await settle()
    check(manager.notifications.last?.hasAction == false, "unrelated error never inherits a previous operation's retry")
    manager.dismissAll()
    manager.errorWithFix("Retry this operation", detail: "Explicit recovery", fixTitle: "Retry", fixHint: "Retry the original operation", fixAction: { Task { await originalRetry() } })
    await settle()
    let actionable = try manager.notifications.last.unwrap("Missing actionable notification")
    check(actionable.hasAction && manager.fixtureScheduledDismissals == 0, "recovery action does not expire while the user reads it")
    manager.recordAction("Newer action", retry: { second += 1 })
    actionable.performAction()
    await settle()
    check(first == 1 && second == 0, "retry uses the captured failing action, not a newer operation")
    manager.dismissAll()
    for index in 0..<10 { manager.info("Notification \(index)") }
    await settle()
    check(manager.notifications.count == 5 && manager.fixtureScheduledDismissals == 5, "notification and timer counts remain bounded")
    manager.dismissAll()
    check(manager.notifications.isEmpty && manager.fixtureScheduledDismissals == 0, "dismiss all also cancels pending timers")
    print("TOAST_INTERACTION_CHECKS: \(checks) checks, \(failures) failures")
    if failures != 0 { exit(1) }
 }
}
extension Optional {
 func unwrap(_ message: String) throws -> Wrapped {
    guard let self else { throw NSError(domain: "GitMacToastFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    return self
 }
}
`);
  const binary = path.join(temporary, 'checks');
  const files = ['Theme.swift', 'AppTheme.swift', 'Notifications.swift', 'Legacy.swift', 'Checks.swift'].map(file => path.join(temporary, file));
  execFileSync('xcrun', ['swiftc', '-parse-as-library', '-swift-version', '5', ...files, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, [output], { stdio: 'inherit', timeout: 60000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
