# Construction visual contract

Original RECLAMATION construction art, authored in `construction_visuals.gd`. This is a visual-only replacement for vertically scaling a finished building. It adds no gameplay data, navigation/collision shapes, costs, build timing, workers, HUD, or help feature.

## Integration

- Create a dedicated `Node3D` child containing the existing final building art. It must not contain gameplay nodes, health labels, rings, or other presentation that should remain visible during construction.
- Call `ConstructionVisuals.setup(building_root, kind, radius, finished_visual)` once; retain its returned `ConstructionState` node or the root's `construction_visuals` metadata.
- Immediately call `state.set_progress(built)`, including after loading a checkpoint and for initially complete buildings.
- Call `set_progress` when `built` changes. The caller removes every former construction-driven change to the simulation root's scale.
- No save-schema field is needed. Recreate this visual state from the existing `built` value.
- Repeated setup with the same kind and finished visual returns the existing state. Explicit `dispose()` restores the final visual's original visibility, removes metadata, and safely queues the helper for deletion. Normal building-root deletion owns its children normally.
- The final visual's transform and geometry are never changed. Construction profiles are authored at the shipped silhouettes' dimensions; radius does not rescale gameplay or final geometry.

The controller begins at materials for buildable structures. HQ always begins and remains complete with no scaffolding or intermediate mesh. `set_progress` clamps finite input to [0,1] and handles NaN/Infinity conservatively as 0. It supports going backwards, as happens when a caller creates a complete visual and then applies a saved partial progress value.

## Visual stages

| Existing progress | Rendered construction |
| --- | --- |
| 0 through below .24 | Ground/foundation outline, footings, stacked materials, folded canvas, work barrier |
| .24 through below .68 | Open load-bearing frame or equipment mounts; final roof/body remains absent |
| .68 through below 1 | Partially fitted roof/cladding or assembled equipment with visible missing pieces and work equipment |
| 1 | Original final art only; construction mesh hidden and released from the active instance |

The unfinished models never use a complete final mesh. The controller does not perform work when progress remains within the same stage. Each buildable instance has one active construction MeshInstance3D and one indexed vertex-color material surface, with three meshes cached per kind across instances. HQ does not create a stage MeshInstance3D. Maximum stage vertex counts range from 852 (wall) to 2,282 (vehicle workshop); these are modest procedural batches, not hundreds of independently submitted primitive nodes.

## Distinct silhouettes

- House: compact gable, timber sill/frame, partial wall and one open roof slope.
- Depot: open-sided lean-to, sloped rafters and a half-fitted rusty sheet roof.
- Training shelter: larger canvas gable, center support poles, low pallet windbreak, unoccupied practice apron. Practice targets and hanging bag appear only with the final art.
- Vehicle workshop: wide steel frame with shallow segmented barrel ribs and partially installed curved sheets.
- Ammunition workshop: narrower steel gable, partial industrial panels; no finished chimney equipment until completion.
- Garden: pegged beds, installed timber bed edges, filled furrows and trellis. No mature crops before completion.
- Tower: footings, lower support frame, empty upper guard platform and side scaffold. No operational gun before completion.
- Relay: anchored mast assembly, raised mast and cabinet; antenna remains laid out on the pad until completion.
- Wall: exposed uprights and reinforcing bar, partial concrete panels and timber shuttering.
- Recovery yard: wide gantry frame and partly fitted gantry cover with side scaffold.
- Mortar: bed rails, mounting turntable and shields; barrel stays on timber cradles, visibly uninstalled.

Amber work barriers remain in every unfinished stage; roofed structures also retain the side scaffold and ladder in the near-complete stage. These cues are geometry, not a persistent label or HUD.

## Primitive provenance

All staging geometry and composition were newly authored for this task. It uses the project's existing `actor_visuals.gd` box, triangle/quad, and prism primitives, combined into original deterministic indexed meshes with `SurfaceTool`. There is no RNG, third-party asset, image generation, network dependency, custom shader, or new library. Colors are original warm salvage timber/cut ends, matte slate steel, rust, sage sheet metal, patch cloth, concrete and amber barriers consistent with the existing building palette. Vertex colors are explicitly interpreted as sRGB.

The review project contains unchanged copies of the shipped final models/materials and supporting geometry scripts solely for side-by-side comparison. They are not replacements for the game assets. The frozen 0.24 and live game files were not edited by this art task.

## Review and verification

- Focused smoke: `godot --headless --path <candidate> --script res://tests/check_construction_visuals.gd`.
- Standalone scene: `godot --path <candidate> res://review/construction_review.tscn`.
- Review keys: Tab changes building group; 1 uses detail camera 28; 2 uses ordinary 42; 3 uses wider 54; F12 saves the current viewport under `review/`; Escape exits the review only.
- CLI options: `-- --review-page=0 --review-zoom=42 --review-capture=/absolute/path.png` (page 0–3).

One bounded smoke covers all 11 buildables plus HQ: finite vertices, one indexed surface per stage, authored bounds (each vertex less than 3m in absolute X/Z, Y in [0,5m)), exact stage boundaries, completion at 1 only, reverse/save-style progress, repeated calls, unchanged gameplay/final transforms, shared setup, disposal, and a removed final visual. Final result: PASS with no Godot script errors.

Native review was performed in the isolated scene using Godot 4.6.3 compatibility rendering on the cloud desktop. Final scene images cover all profiles; camera 42/54 checks establish stage silhouettes remain distinguishable at gameplay scale. This is isolated art review, not a substitute for the parent's earned placement, construction, save/load, and completion checks in the actual mission.

## In-mission comparison

The before/after captures use the same normally paid 15-second state: training shelter 47.33%, house 74%, identical resources, camera and selection. The old shelter already has a complete roof; the replacement shows its open frame. The house shows partial roofing and scaffold.

![Before](screenshots/v25_construction_before.png)

![After](screenshots/v25_construction_after.png)

The construction-only comparison preserved the full saved gameplay state at 21 sampled points, including a construction save/resume. This is evidence for the visual replacement, not an assertion that later combat-spacing changes preserve every unit position.
