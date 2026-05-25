# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_moxyzez1_wwis score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before building in a copied/temp directory, copy pre-resolved SourcePackages from the original project's DerivedData/build output to avoid re-downloading Swift package dependencies.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uciv_yhef score=5.3 created=2026-05-09 source=observation complexity=simple -->
- When installing a macOS .app to /Applications, always kill the running instance with `pkill` before removing and copying the new build to prevent file-lock errors
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moye72i4_apk1 score=5.5 created=2026-05-09 source=observation complexity=simple -->
- After each batch of Swift file edits, immediately run xcodebuild to catch compile errors before proceeding to the next feature
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg24_gdar score=5.7 created=2026-05-24 source=observation complexity=simple -->
- After writing a shell script, immediately run `bash -n <script>` to validate syntax before marking the task complete or executing it.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg4e_xx7u score=5.1 created=2026-05-24 source=anti_pattern complexity=simple -->
- Create tasks incrementally as each step is reached — do not bulk-create TaskCreate entries for all sequential steps upfront only to delete or skip them immediately.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkn70ea_o0ug score=5.3 created=2026-05-25 source=observation complexity=simple -->
- After writing a background data-fix script, immediately poll with pgrep to confirm prior passes have completed before launching subsequent passes.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkn70fh_auaz score=5.3 created=2026-05-25 source=observation complexity=simple -->
- After writing or running a data-fix script, immediately query the target table to verify progress metrics (counts of NULLs vs populated fields) before launching the next phase.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
