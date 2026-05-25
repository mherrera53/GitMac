# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_mpk1egtj_67f3 score=5.3 created=2026-05-24 source=observation complexity=simple -->
- After writing a Python script that generates output files, verify results by inspecting actual file content (ls -la, wc -l, grep/sed samples) before considering the task complete.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk1egus_m1xc score=5.9 created=2026-05-24 source=observation complexity=simple -->
- When a generated output file looks correct but a specific symbol cannot be found with awk range patterns, fall back to grep -n to get the exact line number, then use sed -n 'N,Mp' to extract the relevant block.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk1egvz_bxtt score=5.3 created=2026-05-24 source=observation complexity=simple -->
- Before running a Python script that writes to a directory, always run mkdir -p on the target output directory first.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpk1egx2_bynp score=5.3 created=2026-05-24 source=anti_pattern complexity=simple -->
- When sampling generated Markdown files with awk range patterns (e.g., /^#### header/,/^#### /), verify the pattern matches before relying on it — if output is empty, immediately fall back to grep -n + sed instead of retrying awk.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
