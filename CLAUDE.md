# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_moxyzez1_wwis score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before building in a copied/temp directory, copy pre-resolved SourcePackages from the original project's build_output to avoid re-downloading Swift package dependencies
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moxyzf1h_gqhi score=5 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not poll task output files (cat .output) repeatedly in tight loops without a delay or process check — use pgrep to confirm the background process is still running before re-reading output
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uci0_ul3y score=6.1 created=2026-05-09 source=observation complexity=simple -->
- Before creating a new git version tag, always run `git tag --sort=-v:refname | head -3` to inspect existing tags and avoid version collisions
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uciv_yhef score=7.6 created=2026-05-09 source=observation complexity=simple -->
- When installing a macOS .app to /Applications, always kill the running instance with `pkill` before removing and copying the new build to prevent file-lock errors
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1ucji_eosv score=5.6 created=2026-05-09 source=observation complexity=simple -->
- When about to push a major commit to a shared remote, ask the user for confirmation before executing `git push`
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uck5_0jf6 score=5.6 created=2026-05-09 source=observation complexity=simple -->
- Always run `git pull origin <branch> --rebase` before pushing a new branch or tag to avoid diverged history conflicts
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uckp_t78n score=5.2 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not create a version tag on a local branch before pulling from the remote — tag the commit only after `git pull --rebase` completes to ensure the tag points to the correct, up-to-date HEAD
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1ucl9_s535 score=6 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not push a major feature to a new branch (feat/*) after already tagging on master — decide the target branch before committing and tagging to keep tag ancestry consistent
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1w1sz_q2fc score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before modifying or committing CI-related files, grep all workflow files to identify which scripts and paths they depend on, to avoid removing files that break CI.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1w1to_0eg5 score=5.5 created=2026-05-09 source=observation complexity=simple -->
- When a CI-required script is missing from the working tree, restore it from git history using `git show HEAD~1:<path>` to inspect it first, then `git checkout HEAD~1 -- <path>` to restore it before committing.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
