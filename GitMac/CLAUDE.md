# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_mpk14z88_v9ah score=5.6 created=2026-05-24 source=observation complexity=simple -->
- When auditing build warnings, always filter out SourcePackages/checkouts lines to isolate warnings in the project target only — use `grep -v 'SourcePackages/checkouts'` in every warning count command
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk14z9h_xg1i score=5.4 created=2026-05-24 source=observation complexity=simple -->
- After completing a build audit session, generate and persist summary artifact files (e.g., PERFORMANCE_AUDIT.md, SYMBOL_DICTIONARY.md) in the repo root so findings survive across sessions
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk14zam_0431 score=5.7 created=2026-05-24 source=observation complexity=simple -->
- When checking notarization status, always combine `pgrep` process check with `xcrun notarytool info <uuid>` in a single compound command to get both liveness and status in one call
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk14zbq_98s8 score=5.4 created=2026-05-24 source=observation complexity=simple -->
- When initializing CodeGraph on a project, run `codegraph index --force <path>` if a plain `codegraph index` produces no output or appears to skip files, then verify with `codegraph status` and `codegraph files`
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk14zcu_mfhl score=5.6 created=2026-05-24 source=anti_pattern complexity=simple -->
- Do not redirect full xcodebuild output to a log file and then immediately run multiple separate grep commands against it — pipe output once and extract all needed metrics in a single compound command to avoid redundant reads of large log files
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk14zdw_pnug score=5.4 created=2026-05-24 source=anti_pattern complexity=simple -->
- Do not attempt to read task output files with `cat /private/tmp/.../tasks/<id>.output` when the Bash call itself completed synchronously — check the Bash return output directly instead
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk406pr_67zx score=5.6 created=2026-05-24 source=observation complexity=simple -->
- When wiring new features via NotificationCenter + sheets in ContentView, always grep for the target view's init signature and required parameters before writing the sheet instantiation code, to avoid passing wrong arguments.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk406qz_3fp3 score=5.6 created=2026-05-24 source=observation complexity=simple -->
- After each Edit to ContentView or GitMacApp.swift, verify the file tail with `sed -n` or `tail` to confirm the appended block is syntactically complete before running xcodebuild.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk406s5_ctsy score=5.2 created=2026-05-24 source=observation complexity=simple -->
- When a ViewModifier or extension block must be appended to a Swift file that already has a closing brace, use `cat >>` heredoc only after confirming the file's last line with `tail`, to avoid double-closing braces.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk406t9_9t92 score=5.6 created=2026-05-24 source=anti_pattern complexity=simple -->
- Do not instantiate a SwiftUI view in a sheet without first confirming its init signature — views with required contextual parameters (commit list, branch refs) cannot be safely constructed from a menu entry and must be triggered contextually instead.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
