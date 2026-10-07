# New basic-survivor reconstruction, 7 October 2026

This is newly authored recovery work. It is not restoration of the missing local v0.3.9 model, and no earlier v0.3.9 test result or screenshot is evidence for this candidate.

## Inputs and provenance

- The recovered actor adapter was read from `recovery_oct07/actor_visuals_v039_wip.gd`, SHA256 `5e852c916b44ab52db1ffaa8e1fc49f252919a970a986897359df0f08c16cc5f`.
- The cosmetic movement helper was copied from the verified v0.3.8 source under `recovery_oct07/base_v038/survivor_motion.gd`.
- A scoped source search in the current workspace, shared workspace and temporary directory found no former articulated survivor source. No denied session paths were inspected.
- `articulated_survivor.gd` is original procedural geometry and analytic animation authored for this reconstruction. No model, texture, animation or third-party intellectual property was downloaded or copied.

## Integration files

- `articulated_survivor.gd`: fourteen named parts, one cached `ArrayMesh` and one material surface per part; 1,408 triangles total. Civilian denim jacket and jeans, scarf, baseball cap, hiking daypack, leather boots and original simple rifle silhouette.
- `actor_visuals.gd`: recovered wrapper with an optional final `stride_distance` parameter on `pose` and `sample_pose`, forwarded only for guards. Existing callers remain valid.
- `survivor_motion.gd`: guard-only cosmetic cycle-distance and movement-weight changes. Other unit kinds retain their existing distance phase and movement weights. No actor root position, actual speed, command, combat clock, cooldown, save field or RNG changes.
- `tests/check_new_survivor.gd`: independent geometry, kinematic and adapter checks for this candidate.

The outer renderer and interpolation must iterate `ActorVisuals.parts_for(kind)` and use `muzzle_part_index(kind)` for the fourteen-part guard; the parent integration task owns that glue.

## Movement and weapon contracts

Forward is -Z. All returned transforms are actor-root-local. Mesh limbs extend from their proximal joint along local -Y. Knees and elbows are analytic two-link chains; the pelvis settles as needed to keep legs within reach. Stance feet cancel the actor's forward distance while phase advances by actual distance divided by cosmetic cycle distance. Stop/start weight fades are intentionally transitional rather than exact stance locks.

Cycle distance is clamp(0.8 + speed × 0.32, 0.9, 2.2) meters. At 1.2 m/s cadence is 1.014 cycles/s; at 4.4 m/s it is 2.000 cycles/s. Plant duty changes from 60% walking to 46% jogging. Both hands target the two actual rifle grips. The stock is anchored to the right shoulder. Recoil uses attack age from the real shot timestamp; no invented shot counter or recurring magazine action is introduced.

Vertex colors are explicitly converted from sRGB to linear when emitted, and the shared material disables a second conversion. This is necessary because the Compatibility renderer does not implement the `vertex_color_is_srgb` flag; reference: https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb .

## Verification performed on this new source

Godot 4.6.3 headless compiled and ran `tests/check_new_survivor.gd` on 7 October 2026. Result: PASS. The sampling suite covers six speeds, 120 phases and four attack ages, actual mesh muzzle front-plane center, cache identity/surface count, rigid finite transforms, correct color conversion, joint continuity, both grip constraints, grounded soles, stride cancellation, cadence, timestamp recoil, nonfinite input handling, adapter node count, and actor-root/gameplay-state immutability.

Measured maximum joint discrepancy: 0.0000001384 m. Maximum hand/grip discrepancy: 0.0000001406 m. Lowest foot vertex: 0.0 m. Mesh total: 4,224 triangle-list vertices / 1,408 triangles.

The initial test exposed leg overextension at intermediate strides; cosmetic pelvis settling corrected it and the complete suite was rerun successfully. These are current headless kinematic checks only. Normal-camera visual quality, lighting on asphalt, in-game animation readability, web behavior and performance are not yet validated and must be reviewed in the integrated candidate before visual acceptance.

## Reproduce the focused check

Run from this directory with writable cache/data/config directories:

`XDG_DATA_HOME="$PWD/.data" XDG_CACHE_HOME="$PWD/.cache" XDG_CONFIG_HOME="$PWD/.config" godot --headless --path . --script tests/check_new_survivor.gd`

`project.godot` is an isolated test harness, not a replacement for the game's project configuration. Do not copy its settings into the game project.
