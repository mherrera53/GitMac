# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_moxyzez1_wwis score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before building in a copied/temp directory, copy pre-resolved SourcePackages from the original project's build_output to avoid re-downloading Swift package dependencies
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moxyzf1h_gqhi score=5 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not poll task output files (cat .output) repeatedly in tight loops without a delay or process check — use pgrep to confirm the background process is still running before re-reading output
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
