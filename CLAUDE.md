# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_moxyzez1_wwis score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before building in a copied/temp directory, copy pre-resolved SourcePackages from the original project's DerivedData/build output to avoid re-downloading Swift package dependencies.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uciv_yhef score=5.3 created=2026-05-09 source=observation complexity=simple -->
- When installing a macOS .app to /Applications, always kill the running instance with `pkill` before removing and copying the new build to prevent file-lock errors
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moye72i4_apk1 score=5.1 created=2026-05-09 source=observation complexity=simple -->
- After each batch of Swift file edits, immediately run xcodebuild to catch compile errors before proceeding to the next feature
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg24_gdar score=5.1 created=2026-05-24 source=observation complexity=simple -->
- After writing a shell script, immediately run `bash -n <script>` to validate syntax before marking the task complete or executing it.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg4e_xx7u score=5.1 created=2026-05-24 source=anti_pattern complexity=simple -->
- Create tasks incrementally as each step is reached — do not bulk-create TaskCreate entries for all sequential steps upfront only to delete or skip them immediately.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkozbvr_9x53 score=5.3 created=2026-05-25 source=observation complexity=simple -->
- When a deployed app serves stale bundle hashes, verify the live HTML references with curl before touching any config or triggering a new build.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkqwekk_qaa8 score=6 created=2026-05-25 source=observation complexity=simple -->
- When investigating a DB entity before modifying it, first run a discovery query (by key/name), then fetch the schema/config of the specific record, then inspect related entities — before issuing any UPDATE.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkqwelw_uy2d score=5.6 created=2026-05-25 source=observation complexity=simple -->
- When querying a JSON column from MySQL, pipe the raw output through a Python json parser inline (`python3 -c 'import json,sys; ...'`) to make it readable before acting on it.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkqwen0_xlp0 score=6 created=2026-05-25 source=observation complexity=simple -->
- Before modifying a workflow action in production DB, grep the frontend codebase for references to that form key or route to understand client-side coupling.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpkqweo3_pmaa score=5.8 created=2026-05-25 source=anti_pattern complexity=simple -->
- Do not issue a production UPDATE without first running a SELECT on the exact rows to be modified to confirm row count and current values.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
