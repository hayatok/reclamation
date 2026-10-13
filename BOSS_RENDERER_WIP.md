# Rebuilt demolition boss rendering WIP

Adds authored opaque near/far baked animation to the existing boss without changing damage, windup duration, range, enemy count, or simulation data. Corrects oversized tactical text inherited from the giant body scale. The source asset was regenerated from retained original generators with exact GLB hashes. This is a new reconstructed integration, not restoration of the lost complete candidate.

Native Compatibility rendering checks pass, including transforms, interpolation bounds, fog omission, fallback, and corpse transform handling. A controlled 1.8-second same-camera attack produces exactly equal serialized gameplay state. Normal campaign balance, walking/death appearance, CPU cost and browser/mobile hardware performance are not yet accepted. See docs/boss_rebuilt_review/result.json. Public version remains 0.64.0.
