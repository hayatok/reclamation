# Target candidate cache: bounded AB/BA comparison

Exactly four trials, in order baseline → candidate → candidate → baseline. Each advances the same earned M2 departure fixture for 120 × 0.05 seconds, using Godot 4.6.3 headless and an external instrumentation subclass. Each run has isolated XDG state and output files. No existing source was edited.

## Result

The optimization substantially reduces target-list work: 95.75% in AB and 92.98% in BA. Total simulation work was lower by 16.23% in AB and 4.91% in BA, for a pooled 10.88% reduction. The total-work magnitude is noisy, and p95 was not consistently better; this is evidence for retaining the narrow optimization, not a promised overall or browser speedup.

| Run | Simulation total ms | Mean step ms | p95 step ms | combat_targets total ms | Calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| AB_A_baseline | 1110.775 | 9.256 | 13.143 | 259.893 | 3816 |
| AB_B_candidate | 930.489 | 7.754 | 12.810 | 11.037 | 3816 |
| BA_B_candidate | 944.482 | 7.871 | 14.395 | 16.608 | 3816 |
| BA_A_baseline | 993.203 | 8.277 | 11.388 | 236.425 | 3816 |

## State verification

All four complete starting checkpoint JSON objects deep-match one another. All four complete ending checkpoint JSON objects also deep-match, with no excluded fields, including gameplay, card and visual RNG strings. Every run has 30 allies (14 workers, 12 guards, 2 grenadiers, 1 siege cart, 1 truck), 14 buildings, and enemies change from 43 to 24. This verifies this short earned route only; it does not replace cache lifecycle/edge-case checks.

Every run exited 0 and reported no script/runtime errors. Both baseline runs reported ObjectDB cleanup warnings at exit; neither candidate run did. Source main.gd SHA256 values remained unchanged.

Baseline main.gd: c0f921f2be3c6e72a9bd3e6debb4bd0b3c52bc1470a56f56aed373dcf1f3cf59

Candidate main.gd: 8793a487d8d43fa15ff65c985febe29a12e30ad216de5fced0faed21660af3c6

## Limits and artifacts

Times measure elapsed CPU-work wall time around simulate() and the tested combat_targets(), including instrumentation. Startup, checkpoint capture and rendering are outside the timing. This is not process CPU time or a browser/device/FPS measurement.

The counter query_enemy_entries_virtual adds the current enemy-array length at each target query; it must not be described as actual scans for the cached candidate. target_results_returned may include dead cached references that existing callers reject live; it is not an outcome comparison.

comparison.json contains timing statistics, source/checkpoint hashes, exact RNG strings and full-state comparison results. Four per-run result files and one copy of the identical start/end state are retained here. The portable profiler and instrumentation are in tests/combat_candidate_profile. Pass an existing writable output directory as its first user argument. Startup/output paths are outside the measured section.

## Lifecycle acceptance

An independent code review found no direct simulate_world callers or asynchronous yields. Twelve focused checks pass: visible membership/reuse, live death exclusion, spawn invalidation, known/dead/unknown nest states, visibility changes outside the cached phase, forced refresh invalidation, normal cleanup and HQ-loss early cleanup. tests/check_combat_candidate_cache.gd records those boundaries. M1/M3 retain the direct enemies collection. Cache state is transient and is not serialized. Neither army/enemy counts nor rendering quality changes. No browser/device speedup or p95 improvement is claimed.
