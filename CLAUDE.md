# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_moxyzez1_wwis score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before building in a copied/temp directory, copy pre-resolved SourcePackages from the original project's build_output to avoid re-downloading Swift package dependencies
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moxyzf1h_gqhi score=5 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not poll task output files (cat .output) repeatedly in tight loops without a delay or process check — use pgrep to confirm the background process is still running before re-reading output
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uci0_ul3y score=5.3 created=2026-05-09 source=observation complexity=simple -->
- Before creating a new git version tag, always run `git tag --sort=-v:refname | head -3` to inspect existing tags and avoid version collisions
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uciv_yhef score=7.9 created=2026-05-09 source=observation complexity=simple -->
- When installing a macOS .app to /Applications, always kill the running instance with `pkill` before removing and copying the new build to prevent file-lock errors
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1ucji_eosv score=6.6 created=2026-05-09 source=observation complexity=simple -->
- When about to push a major commit to a shared remote, ask the user for confirmation before executing `git push`
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1ucl9_s535 score=6.9 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not push a major feature to a new branch (feat/*) after already tagging on master — decide the target branch before committing and tagging to keep tag ancestry consistent
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moye72go_tbz1 score=5.9 created=2026-05-09 source=observation complexity=simple -->
- Before modifying any Swift service or view file, run grep to map key symbols (functions, enums, structs) before reading the full file
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moye72i4_apk1 score=5.9 created=2026-05-09 source=observation complexity=simple -->
- After each batch of Swift file edits, immediately run xcodebuild to catch compile errors before proceeding to the next feature
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moyhuhq4_co12 score=5.4 created=2026-05-09 source=observation complexity=simple -->
- When using a specific error type in a Swift view or feature file, grep the target file's imports and the error type's declaration to confirm it is accessible from that scope before using it — prevents follow-up edits to replace inaccessible types
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moyhuhqy_5kr0 score=5.1 created=2026-05-09 source=observation complexity=simple -->
- When research requires more than 2 web searches on the same topic, launch a research Agent instead of making sequential WebSearch calls — the Agent parallelizes searches and synthesizes results more efficiently
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
