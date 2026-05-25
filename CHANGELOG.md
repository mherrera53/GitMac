# Changelog

All notable changes to GitMac are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Workflow engine with visual pipeline builder
- Smart commit with AI-generated messages
- Prompt template editor for AI providers
- Repository health dashboard
- Sync wizard for push/pull/fetch workflows
- AI pull request review sheet
- Conflict prevention detector (sidebar navigator tab)
- Worktrees sidebar section
- Git hooks management UI
- CI/CD pipeline sidebar section
- Subscription paywall and SubscriptionService

### Fixed
- Branch selection not updating in sidebar/toolbar after checkout
- `<think>` reasoning tags leaking into AI-generated PR titles and commit messages
- Diff view rendering regressions
- Commit graph hang caused by GPG verification (`%G?`) blocking git log
- Crash on launch when `applyTheme()` ran before `NSApp` was ready
- `ShellExecutor` actor blocking causing commit graph spinner to stall

### Performance
- Native MLX on-device AI inference (no network required)
- `ShellExecutor.execute` made `nonisolated` for true parallel git operations
- Incremental commit graph loading to avoid UI stalls

---

## [1.0.0] — 2025-12-01

### Added
- Initial release: repository browser, commit graph, diff viewer, branch manager
- Ghostty terminal integration
- GitHub pull request integration
- AI commit message generation (OpenAI, Anthropic, Ollama, MLX)
- GPG/SSH key management
- Submodule support
- Dark/light theme system with custom theme editor
