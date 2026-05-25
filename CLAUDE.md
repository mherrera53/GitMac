# CLAUDE.md

## Auto-learned Rules

<!-- claude-evolve:managed-start -->

<!-- claude-evolve:rule id=r_moxyzez1_wwis score=5.1 created=2026-05-09 source=observation complexity=simple -->
- Before building in a copied/temp directory, copy pre-resolved SourcePackages from the original project's build output to avoid re-downloading Swift package dependencies.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moxyzf1h_gqhi score=5.4 created=2026-05-09 source=anti_pattern complexity=simple -->
- Do not poll task output files in tight loops — use pgrep to confirm the background process is still running before re-reading output, and add a delay between checks.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moy1uciv_yhef score=6.3 created=2026-05-09 source=observation complexity=simple -->
- When installing a macOS .app to /Applications, always kill the running instance with `pkill` before removing and copying the new build to prevent file-lock errors
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_moye72i4_apk1 score=5.3 created=2026-05-09 source=observation complexity=simple -->
- After each batch of Swift file edits, immediately run xcodebuild to catch compile errors before proceeding to the next feature
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtfzo_ngr1 score=5.3 created=2026-05-24 source=observation complexity=simple -->
- Before signing or notarizing a macOS .app, inspect all embedded frameworks and binaries with `codesign -dvvv` to confirm their current signing state and identify nested components that need deep signing.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg0w_2o5t score=5.3 created=2026-05-24 source=observation complexity=simple -->
- When creating a DMG packaging script, always include: build → codesign --options runtime --deep → notarytool submit --wait → stapler → hdiutil create, in that exact order.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg24_gdar score=5.1 created=2026-05-24 source=observation complexity=simple -->
- After writing a shell script, immediately run `bash -n <script>` to validate syntax before marking the task complete or executing it.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg3b_qnem score=5.1 created=2026-05-24 source=observation complexity=simple -->
- When diagnosing a macOS DMG 'damaged' or Gatekeeper error, first mount the DMG with `hdiutil attach -nobrowse -readonly` and inspect the .app's signing inside the mounted volume, not just the build output.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjwtg4e_xx7u score=5.5 created=2026-05-24 source=anti_pattern complexity=simple -->
- Do not create multiple TaskCreate entries for sequential steps of the same workflow upfront and then immediately delete or skip them — instead create tasks incrementally as each step is reached to avoid task bloat and premature deletion.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:rule id=r_mpjxu9l4_raq2 score=5.1 created=2026-05-24 source=observation complexity=simple -->
- When notarytool credentials are missing or failing, verify keychain profile existence by running both `xcrun notarytool history --keychain-profile <profile>` and `security dump-keychain` before asking the user to re-enter credentials.
<!-- /claude-evolve:rule -->

<!-- claude-evolve:managed-end -->
