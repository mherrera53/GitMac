# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_moxyzez1_wwis score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before building in a copied/temp directory, copy pre-resolved SourcePackages from the original project's build output to avoid re-downloading Swift package dependencies.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moxyzf1h_gqhi score=5.1 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not poll task output files in tight loops — use pgrep to confirm the background process is still running before re-reading output, and add a delay between checks.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uciv_yhef score=5.3 created=2026-05-09 source=observation complexity=simple -->
- When installing a macOS .app to /Applications, always kill the running instance with `pkill` before removing and copying the new build to prevent file-lock errors
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moye72i4_apk1 score=5.5 created=2026-05-09 source=observation complexity=simple -->
- After each batch of Swift file edits, immediately run xcodebuild to catch compile errors before proceeding to the next feature
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg24_gdar score=5.1 created=2026-05-24 source=observation complexity=simple -->
- After writing a shell script, immediately run `bash -n <script>` to validate syntax before marking the task complete or executing it.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg4e_xx7u score=5.4 created=2026-05-24 source=anti_pattern complexity=simple -->
- Do not create multiple TaskCreate entries for sequential steps of the same workflow upfront and then immediately delete or skip them — instead create tasks incrementally as each step is reached to avoid task bloat and premature deletion.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkm2l29_f575 score=5.3 created=2026-05-25 source=observation complexity=simple -->
- When querying production DICOM/study data, always run a COUNT/aggregate query first before fetching full rows — confirm scale before pulling raw records
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkm2l3e_0l78 score=5.9 created=2026-05-25 source=observation complexity=simple -->
- Before running a DELETE on production cascade tables (e.g., workflows_dicom_files → workflows_dicom_series → workflows_dicom_studies), verify the target study IDs exist and are correct via a SELECT query in the same session
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkm2l4h_tenb score=5.9 created=2026-05-25 source=observation complexity=simple -->
- After a production DELETE on DICOM tables, immediately run a SELECT on the parent table to confirm the expected rows were removed and remaining data is intact
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkm2l5i_7u9t score=5.3 created=2026-05-25 source=anti_pattern complexity=simple -->
- Do not read raw task output files with cat/tail in sequence — if the first cat call returns the needed data, do not immediately re-tail the same file; check stdout from the first call before issuing a redundant tail
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
