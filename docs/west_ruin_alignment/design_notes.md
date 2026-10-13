# City shell navigation: bounded prototype

Prepared against the current reconstruction on 2026-10-13. This directory is an isolated proposal. The worker did not edit the working main/world scripts or launch Godot.

## Scope and choice

Activate navigation for exactly one existing ruin: shell index 4, the west middle shell at `(-28.1, 0, -7)`, size `(6.4, 8.5, 14)`. The eight original shell records remain the shared authoritative art layout in their original order. Every position, size, story count and damage flag matches the removed `_make_district` calls exactly. Art continues to render all eight and consumes the same RNG calls in the same order.

The prototype applies only to mission indexes 0 and 2 (M1/M3). M2 still uses its frontier art/navigation branch and receives no city blockers or spawn correction.

Blocking all eight at once is not safe. With the existing `.4` terrain padding, the original west/north/east spawn strips retain only 27/15/30 open integer cells. They are not entirely closed, but M3's `outer_parts` resource at `(-20, -15)` becomes enclosed by the northwest shell, the west middle shell, the facility and the tactical cover. The same change blocks M3's fixed boss source `(-25, -18)`. Neither problem occurs with the one-shell prototype. Do not change the active index list to all eight without redesigning and rechecking those approaches.

## Integration

1. Copy `city_ruin_layout.gd` to the project root next to `main.gd`.
2. Apply `integration.patch` from that project root with `patch -p1`.
3. Run the focused native checks below before treating the prototype as accepted.

The patch touches only main/world integration points. `tactical_map.gd` and `enemy_navigation.gd` remain unchanged. Append city records to main's `terrain_blocks`, not `TacticalMap.blockers_for`: otherwise TacticalMap would also create new cover visuals over the existing buildings.

The city record uses main's existing terrain contract: `size * .5 + (.4, 0, .4)`, floor/ceil inclusive, clipped to the nav grid. The active shell therefore blocks x `[-32,-24]`, z `[-15,1]` before clipping. At this stage the entire authored shell footprint is impassable; visible facade breaches do not promise enterable rooms. It is a navigation/placement contract, not new per-piece physical collision.

Adding the record to `terrain_blocks` also makes the existing placement overlap check and minimap understand that shell. No global rule requires a path from enemies to HQ, reserves an unbuildable route, or rejects a player enclosure.

## Spawn contract

- An unblocked candidate keeps its original floating point coordinates exactly.
- A blocked candidate chooses the nearest open integer cell from the same original strip: west x `[-29,-27]`, z `[-20,15]`; north x `[-24,24]`, z `[-29,-27]`; east x `[27,29]`, z `[-20,15]`.
- No inward fringe is used. The correction never moves a western entry to x `-23` or selects an HQ-side destination.
- Distance is squared planar distance. Exact ties prefer lower x, then lower z. The selected point keeps the requested y.
- If that entire original strip is blocked, choose the closest same-side outer nav rim cell with the same transverse limits: west x `-31`, north z `-31`, east x `31`. Since the normal coordinate is constant there, this selects the nearest original transverse coordinate with the same deterministic tie rule.
- Entry and rim candidates are rebuilt only after the complete navigation rebuild. They incorporate terrain, player buildings and facility footprints. Spawning scans only that small cached side array, never the whole map or AStar.
- There are no new random draws, changes to spawn count, enemy speed/type rules, or save data. The existing two position draws and `spawn_enemy` cooldown draw retain their ordering.

The outer rim remains inside the 64m rendered ground and the existing nav region, although it is one cell outside player command/playable bounds. Enemy movement already uses the nav grid and does not clamp each step to the player bounds. The fallback therefore approaches from outside the same side, rather than appearing inside the defended area. Native visual/movement verification is still required.

## Fully blocked-side behavior and bound

For the one-shell layout, the rim has 19 west, 49 north and 36 east open cells. Player buildings must fit their full radius within build bounds `[-29,29]`. Applying the existing `.3` building navigation pad and inclusive floor/ceil can extend a legal footprint only to `[-30,30]`. Thus no union of currently allowed player building footprints can erase any of those remaining x/z `±31` rim cells. This holds for all 11 buildable building records and their actual radii, not just walls.

As a stronger static check, saturating every cell of the entire `[-30,30]²` square still leaves exactly 19/49/36 open rim candidates. This proves open arrival cells; it intentionally does not promise a route through player fortifications to HQ. Player enclosures and their normal attack/blocking behavior remain meaningful.

If exotic terrain mutation or an invalid map removes even every rim candidate, the normal wave scheduler pauses and reports an error before incrementing the wave or generating any spawn RNG. The current wave remains due. It must be diagnosed before resuming; there is no pending-arrival/save system. Direct calls to the helper in such an unsupported state return `Vector3.INF` with an explicit error. Callers outside the patched normal wave scheduler must preflight and must never pass that sentinel to `spawn_enemy`.

## Completed checks

These are static Python geometry/contract checks, not a Godot parse or runtime pass:

- All eight art tuples exactly match the original calls, including order and textual numeric values.
- Patch dry-run passed against both original working files.
- Replicated current grid padding, mission tactical cover, HQ and site footprints, then used cardinal connectivity from the starting guard component. M1 retained all 11 resource/site work perimeters; M3 retained all 12. Baseline counts match the separate native baseline report.
- The one-shell prototype has west/north/east original-strip open counts 57/147/108 on both city missions; rim counts are 19/49/36.
- Every blocked integer source in all three original strips resolves to an open same-side original-strip cell in the ordinary one-shell layout.
- All buildable radii satisfy the outer-rim bound, including the conservative full-interior saturation described above.
- All-eight comparison retains M1 11/11 work perimeters, but M3 drops to 11/12 with `outer_parts` unreachable. Existing blocked resource centers alone were not treated as failures; the test uses the real padded work-perimeter geometry.
- The helper contains no RNG calls or AStar path queries.

## Focused native acceptance

1. Parse/load the helper and patched scene in the existing supported native test flow. Keep the checks small; no large horde benchmark or export is needed for this prototype.
2. Rerun the existing `check_city_routes.gd` check. M1 must retain 11/11 approaches, M3 12/12, and the west sample cell `(-25,-7)` must now be solid. Keep initial worker/guard movement and at least one nearest depot/resource delivery loop usable.
3. Repeat exactly the baseline M1 west wave 3 at seed 731054. Preserve all 12 enemies, type/speed order and post-wave RNG state. The previously blocked source cells must be corrected; every originally open float source must be byte-for-byte/value-for-value unchanged. Observe one ordinary wave routing around the shell rather than through the masonry.
4. Verify an M3 mixed-side wave preserves its two requested sides, count/types/speeds and RNG. The unchanged fixed boss source is outside the active shell; test any future all-eight expansion separately.
5. Exercise a blocked original strip with the allowed building-footprint envelope. Correction must use the same-side outer rim. Observe an enemy move inward from an open rim cell, and verify it does not appear past a wall. A sealed player base need not have an open route to HQ.
6. Rebuild after adding and removing a wall. Cached candidates must match the revised grid. Test the exotic all-strip-plus-rim blocked guard once: the wave number, wave RNG, enemy list and surge flag must be untouched, the wave clock still due, and the game explicitly paused/error-reported.
7. Check M2 blockers and spawn positions are unchanged. City missions have no frontier fog state; no frontier fog/performance suite is needed here. Inspect the eight city buildings once for unchanged geometry/material ordering.

The isolated patch does not relocate enemies already embedded in geometry in an old checkpoint. Test fresh city missions for this bounded change. A migration or a broader all-city traversal design is separate work.

## Original integration inputs

SHA-256 before integration:

- `main.gd`: `e35aeaa2180f28a9771a2c402e4dd636cdf1b9346ac2623f3a14948093fd82ac`
- `world_art.gd`: `60f48619e1327f6c4c39c92f747f975087541a8028b62944a78de8ab8c62bb57`
- `tactical_map.gd`: `ff58a942c7d770dd45c6be9e402d62a932b5badb5b909dd462ef78fdb5e0b86b`
- `enemy_navigation.gd`: `5f245e1fad60455f75b48774c90a1631168167aa7d1c988c80878551b09ddb99`
