# Working checkpoint: worker order queues

This is an unfinished source checkpoint for the next development cycle, built on the recovered v0.25 runtime below. It adds worker-only Shift orders and targeted save handling. The engine project version remains the v0.25 development base until the next release is validated. It is not a v0.26 release. Native mouse/keyboard validation is still pending.

The remainder records the recovered baseline, not the hashes of newly changed working files. Use the current SOURCE_MANIFEST.sha256 for this checkout.

# v0.25 runtime source recovery checkpoint

The 668 recovered original files, including every game runtime source, asset and project/export setting, match their recorded pre-loss SHA-256 values. `main.gd` matches `83b16b8a1225f03789384ff190cbce0f23633c4dbd868ee91535c418603bb69e`. The original README, design notes and ending video are preserved unchanged.

This is not the complete original 689-file source archive or the original distribution packages. The missing items below are comparison screenshots, their importer metadata, test UID sidecars and two earned-play test states plus their review script. Do not treat those absent captures or states as recovered. Historical verification described in the retained notes occurred before the environment change; new runtime verification has not yet been performed on this recovered copy.

`SOURCE_MANIFEST.sha256` describes this complete recovery checkpoint. `ORIGINAL_SOURCE_MANIFEST.sha256` preserves the original v0.25 inventory, whose SHA-256 is `6bb92d559a2c30eb5dd32cebe64cd7b353eb5008912088b11b212bf04210f9b8`; missing entries there are not claims that files are present.

## Original files not recovered

- `docs/screenshots/v25_construction_after.png`
- `docs/screenshots/v25_construction_after.png.import`
- `docs/screenshots/v25_construction_before.png`
- `docs/screenshots/v25_construction_before.png.import`
- `docs/screenshots/v25_ending_after.png`
- `docs/screenshots/v25_ending_after.png.import`
- `docs/screenshots/v25_ending_before.png`
- `docs/screenshots/v25_ending_before.png.import`
- `docs/screenshots/v25_prerequisite.png`
- `docs/screenshots/v25_prerequisite.png.import`
- `docs/screenshots/v25_spacing_after.png`
- `docs/screenshots/v25_spacing_after.png.import`
- `tests/check_aftermath_transition.gd.uid`
- `tests/check_combat_spacing.gd.uid`
- `tests/check_combat_spacing_safety.gd.uid`
- `tests/check_command_block_reasons.gd.uid`
- `tests/fixtures/earned_m1_last_second.json`
- `tests/fixtures/earned_m1_late_hold.json`
- `tests/review_earned_m1_completion.gd`
- `tests/review_earned_m1_completion.gd.uid`
