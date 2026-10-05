# Mission facility navigation

Mission facilities now contribute stable solid cells to the existing navigation grid. Generator, rail-depot, central-station and refuge-substation pads use half-extents of 2.1 × 1.75 m. The first mission's water station uses 2.12 × 2.12 m. Both use the existing constructed-building clearance of 0.3 m and inclusive floor/ceil cell bounds. All authored integer anchors occupy a 7 × 7 cell footprint. Reclamation does not change that footprint.

The footprint derives from the site kind and mission mode when the site is created, rather than from meshes, imported physics or visual state. The same geometry supplies the solid grid and bounded work perimeter. Every site creation rebuilds navigation, including initial creation after the HQ and checkpoint reconstruction. Later building rebuilds retain all site obstacles. Movement, attack-move, minimap orders, enemy routing and local combat separation continue to consume their existing shared grid.

Restoration uses the same transient work-cell reservations and bounded alternate-approach search as construction/repair. Workers choose distinct reachable cells immediately outside the site footprint, wait when reachable cells are occupied, and report no route when every work approach is blocked. A generic projected movement endpoint outside this perimeter cannot progress restoration. Work requires the actor's own reserved, open perimeter cell and actual arrival. Completion, cancellation, death or target disappearance releases reservations. A completed target also releases workers who were waiting or still approaching.

Enemy approaches to solid buildings also filter out projected cells beyond the existing 2.5 m empty-route attack allowance. This fixes an enemy repeatedly choosing the same unreachable-to-attack HQ corner after detouring around a site. The original allowance, attack behavior, 32-query budget and negative-path cache remain unchanged.

Restoration costs, one-time payment, work durations, age requirements, mission goals, enemy counts, resources and unit speeds are unchanged. This is not a new movement collision system or a pathfinder replacement. Scrap-site behavior remains on its prior path.

## Checkpoints

Schema 3 remains in use. The checkpoint persists actor coordinates, ordinary site orders, progress and paid state. Footprints derive again from site kind/mission mode, and reservations reconstruct during the first simulation step. There are no serialized node IDs or work reservations.

A checkpoint with a friendly unit inside newly solid facility cells is rejected by validation before any live scene object is replaced. The existing recovery mechanism can use a valid backup; if none is valid, Continue follows its existing failure behavior and a new operation must be started. No coordinates are moved, old saves rewritten, or migration added. A stale saved approach goal is harmless when the actor itself occupies a valid cell, because the next site approach is derived from its target.

## Focused verification

New test: `tests/check_mission_site_navigation.gd`. It requires a fresh isolated `XDG_DATA_HOME` and refuses to overwrite an existing `user://settlement_v2` directory. It uses controlled fixtures, including specified stockpiles, suppressed waves, and direct fixture geometry; it is not campaign-playthrough evidence.

Coverage prepared:

- Every authored mission site's footprint on the first frame, persistence across later construction and reclamation, and normal later site creation.
- Ground move, Q attack-move and minimap commands across and into all seven authored facilities from fractional starts. This motion fixture clears unrelated terrain; separate M3 restoration fixtures preserve authored pipes.
- Idle and fire-holding separation at a facility edge; ordinary enemy pursuit around a facility to an HQ.
- A sealed preferred work side with a reachable alternate; a fully enclosed paid site; an unpaid site with no valid perimeter even though generic movement projection can find a distant endpoint; reopening and cancellation.
- One reachable work cell with three workers, occupied-cell waiting without repeated path queries, completion releasing waiters without moving them, and the unchanged settlement-age gate.
- Actual atomic saves and new scene construction at mid-approach, mid-work and reclaimed states; six reserved positions after restart; one payment; invalid old position rejection without replacing live actors.
- Six workers restoring all three M3 facilities with authored pipe blockers intact, and unchanged power/hold/boss requirements.
- Both M2 convoy roads reaching the ordinary victory condition with site obstacles intact and the unchanged launch cost.
- Movement remains open and speed-limited; friendly and enemy query budgets are checked during every observed simulation step.

Regression fixtures passed in separate fresh user-data directories: `check_recovery_navigation.gd`, `check_work_approaches.gd`, `check_work_positions.gd`, `check_work_positions_integration.gd`, `check_recovery_orders.gd`, `check_minimap_commands.gd`, `check_camera_resume.gd`, `check_water_station_integration.gd`, `check_enemy_navigation.gd`, `check_combat_spacing.gd`, `check_combat_spacing_safety.gd`, `check_checkpoint_integrity.gd`, `check_checkpoint_production_waiting.gd`, and `check_worker_queue_removal_saves.gd`.

The water-station visual fixture now travels to a real reserved work position before invoking its completion hook. Its M3 visual expectation also reflects the central-station art already present in the baseline. The recovery-order fixture explicitly rebuilds navigation after moving a site as part of its controlled setup.

## Verified results

Godot 4.6.3 headless validation passed on the final candidate: the focused mission-site fixture passed 164 checks with zero failures, and all 14 related regression scripts exited successfully with no script errors or failed assertions. The main script also passed check-only parsing. The enemy regression confirmed the existing 32-query budget, bounded alternate probes, negative-result cache, 300/500-enemy recovery, FIFO fairness and unchanged RNG behavior.

The first focused run exposed the HQ corner-approach issue described above; the corrected candidate passes that scenario. It also exposed an invalid test assumption: the generic `shots` field is not incremented for guards. The final fixture verifies each guard's recorded firing time and actual enemy damage instead.

A separate Python integer-grid connectivity audit matches the authored M3 geometry: generator, central station and substation have 20, 19 and 28 reachable perimeter cells respectively. Runtime tests additionally restored all three with six distinct worker positions.

Several scene fixtures emit an ObjectDB cleanup warning when exiting. Malformed-checkpoint fixtures also produce expected JSON warnings. No final test timed out or exited unsuccessfully. Native visual/playthrough, macOS and Web behavior remain unverified for this change. The pre-change live project and its user-data directory were not modified.
