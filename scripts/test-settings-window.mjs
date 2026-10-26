import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'gitmac-settings-window-'));
try {
  for (const file of ['GeneralSettingsTab.swift', 'AISettingsTab.swift', 'KeyboardShortcutsTab.swift']) {
    const page = await fs.readFile(path.join(root, 'GitMac/Features/Settings/Tabs', file), 'utf8');
    assert(page.includes('SettingsPage {'), `${file}: shared scrolling container missing`);
  }
  console.log('SHARED_SETTINGS_PAGES=3');
  let source = await fs.readFile(path.join(root, 'GitMac/Features/Settings/SettingsView.swift'), 'utf8');
  if (process.argv.includes('--fixed-size-control')) {
    const constraint = '.frame(minWidth: SettingsWindowMetrics.minimum.width, idealWidth: SettingsWindowMetrics.preferred.width, maxWidth: .infinity,\n               minHeight: SettingsWindowMetrics.minimum.height, idealHeight: SettingsWindowMetrics.preferred.height, maxHeight: .infinity)';
    assert(source.includes(constraint), 'Native size mutation boundary changed');
    source = source.replace(constraint, '.frame(width: 850, height: 550)');
    console.log('NEGATIVE CONTROL: fixed frame in disposable source only');
  }
  if (process.argv.includes('--eager-control')) {
    const marker = '.onAppear {\n';
    assert(source.includes(marker), 'Eager mutation boundary changed');
    source = source.replace(marker, marker + '            _ = AccountsSettingsView()\n');
    console.log('NEGATIVE CONTROL: eager inactive pane in disposable source only');
  }
  const panes = {
    GeneralSettingsView: 'general', AccountsSettingsView: 'accounts', IntegrationsSettingsView: 'integrations',
    AISettingsView: 'ai', GitConfigView: 'git', WorkflowSettingsView: 'workflows',
    WorkspaceConfigView: 'workspace', KeyboardShortcutsView: 'shortcuts', SubscriptionSettingsView: 'subscription',
  };
  const fixtures = Object.entries(panes).map(([type, category]) => `
@MainActor struct ${type}: View {
  init() { PaneRegistry.created["${category}", default: 0] += 1 }
  var body: some View { Text("${category} fixture").frame(width: ${category === 'workflows' ? 3000 : 300}, height: ${category === 'workflows' ? 4000 : 250}) }
}`).join('\n');
  const harness = `import AppKit
import SwiftUI
import Observation
enum Theme { case system, light, dark, custom }
struct FixtureBackground { var isLight = false }
struct FixtureColors { var background = FixtureBackground() }
@Observable @MainActor final class ThemeManager {
  var currentTheme: Theme = .system
  var colors = FixtureColors()
}
enum AppTheme {
  static let background = Color.gray
  static let backgroundSecondary = Color.gray.opacity(0.2)
  static let accent = Color.blue
  static let textPrimary = Color.primary
}
@MainActor enum PaneRegistry { static var created: [String: Int] = [:] }
${fixtures}
@main struct SettingsWindowCheck {
  @MainActor static func main() async throws {
    _ = NSApplication.shared
    let suite = "com.gitmac.settings-test." + UUID().uuidString
    let preferences = UserDefaults(suiteName: suite)!
    defer { preferences.removePersistentDomain(forName: suite) }
    preferences.set("retired-feature", forKey: "settingsSelectedTab")
    let theme = ThemeManager()
    let host = NSHostingView(rootView: SettingsView().environment(theme).defaultAppStorage(preferences))
    let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 900, height: 620),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = host
    window.orderFront(nil)
    var failures = 0
    func check(_ value: Bool, _ label: String) {
      print("\\(value ? "PASS" : "FAIL") " + label)
      if !value { failures += 1 }
    }
    func settle() async throws {
      try await Task.sleep(nanoseconds: 200_000_000)
      host.layoutSubtreeIfNeeded()
    }
    try await settle()
    check(preferences.string(forKey: "settingsSelectedTab") == "general", "invalid persisted selection recovers to General")
    check(PaneRegistry.created["general", default: 0] > 0
      && PaneRegistry.created.keys.allSatisfy { $0 == "general" }, "inactive settings panes are not initialized")
    let ideal = host.fittingSize
    let minimum = window.contentMinSize
    print("NATIVE_MINIMUM \\(minimum.width)x\\(minimum.height)")
    window.setContentSize(NSSize(width: 660, height: 400))
    try await settle()
    let measurer = NSHostingController(rootView: host.rootView)
    let compact = measurer.sizeThatFits(in: NSSize(width: 660, height: 400))
    check(minimum.width <= 660 && minimum.height <= 400
      && host.frame.width <= 660 && host.frame.height <= 400
      && compact.width <= 660 && compact.height <= 400, "native minimum permits compact settings window")
    check(SettingsCategory.allCases.count == 9 && Set(SettingsCategory.allCases.map(\\.rawValue)).count == 9,
      "nine unique settings categories remain available")
    window.setContentSize(NSSize(width: 660, height: 400))
    for category in SettingsCategory.allCases {
      preferences.set(category.rawValue, forKey: "settingsSelectedTab")
      try await settle()
      check(PaneRegistry.created[category.rawValue, default: 0] > 0, "selected pane renders: " + category.rawValue)
      check(window.contentMinSize == minimum && host.fittingSize == ideal, "pane does not change native constraints: " + category.rawValue)
    }
    for appearance in [Theme.light, .dark, .system] {
      theme.currentTheme = appearance
      try await settle()
      check(window.contentMinSize == minimum && host.fittingSize == ideal, "appearance change preserves native constraints")
    }
    for isLight in [true, false] {
      theme.colors.background.isLight = isLight
      theme.currentTheme = .custom
      try await settle()
      check(window.contentMinSize == minimum && host.fittingSize == ideal, "custom theme preserves native constraints")
    }
    window.close()
    print("SETTINGS_WINDOW_CHECKS: \\(failures) failures")
    if failures != 0 { exit(1) }
  }
}
`;
  const view = path.join(temporary, 'SettingsView.swift');
  const main = path.join(temporary, 'SettingsWindowMain.swift');
  await fs.writeFile(view, source); await fs.writeFile(main, harness);
  const compiler = execFileSync('xcrun', ['--find', 'swiftc'], { encoding: 'utf8' }).trim();
  const sdk = execFileSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path'], { encoding: 'utf8' }).trim();
  const binary = path.join(temporary, 'settings-window-tests');
  execFileSync(compiler, ['-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-macosx14.0', '-sdk', sdk,
    view, main, '-o', binary], { stdio: 'inherit', timeout: 120000 });
  execFileSync(binary, [], { stdio: 'inherit', timeout: 30000 });
} finally { await fs.rm(temporary, { recursive: true, force: true }); }
