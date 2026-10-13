# Original demolition infected

An original civilian-world demolition infected for RECLAMATION. The sloping
shoulder hump surrounds a recessed head; one forearm is larger and carries
broken concrete and bent rebar. A torn ochre work coat, faded blue trousers,
separated bent knees, and heavy worn shoes retain the former civilian silhouette.
This asset contains no third-party geometry, imagery, or character design.

Runtime GLBs and their extracted textures live in `assets/models` in the game repository. The editable Blend is reproducible but omitted from this checkpoint because its internal UI history contains local absolute paths. Python geometry/motion generators and the original atlas are included. Running them creates local `generated` and `review` directories.

## Generated outputs

- `source/build_boss_poses.py`: editable Blender geometry and motion generator.
- `source/create_boss_atlas.py`: deterministic original painted-surface atlas.
- `source/finalize_boss_glbs.py`: lossless GLB pose-name normalization.
- `source/validate_boss_glb.py`: CPU-only geometry and animation-contract validation.
- `generated/demolition_boss_near.glb`: 44 poses, 1112 triangles per pose.
- `generated/demolition_boss_far.glb`: 44 poses, 408 triangles per pose.
- `generated/demolition_boss_atlas.png`: one shared opaque 512 × 512 atlas.
- `generated/demolition_boss_source.blend`: optional local inspection scene;
  excluded from distribution because Blender embeds environment-local paths.
- `generated/boss_manifest.json`: timings, topology signatures, hashes and sizes.
- `review/glb_contract.json`: actual checks on both exported GLBs.
- `review/front.png`, `three_quarter.png`, `back.png`, `rts.png`: authoring views.
- `review/pose_contact_sheet.png`: CPU-only geometric pose sequence overview.

## Rebuild

Run from this directory with Python/Pillow, NumPy, and Blender installed:

```sh
python source/create_boss_atlas.py
blender --background --factory-startup --threads 2 --python source/build_boss_poses.py -- --render
python source/validate_boss_glb.py
python source/render_pose_contact_sheet.py
```

The generator starts from a factory scene. It never reads an existing user
Blender file. Distribute the Python, atlas and GLBs; the optional local Blend is
not the portable source deliverable. All Python sources resolve paths relative
to their own directory.

## Runtime contract

The GLBs are skeleton-free, material-shared pose libraries. Each pose is one mesh
node with an identity transform and one surface. Pose names are `idle_00`,
`walk_00`, `windup_00`, `recovery_00`, `death_00`, continuing to the counts below.
Coordinates are meters, Godot +Y up and −Z forward. Unscaled idle height is
approximately 1.624 m; runtime scale remains the caller's responsibility.

| Clip | Duration | Frames | Loop |
| --- | ---: | ---: | --- |
| idle | 1.8 s | 2 | Yes |
| walk | 1.0 s | 12 | Yes |
| windup | 1.4 s | 12 | No |
| recovery | 0.9 s | 8 | No |
| death | 1.2 s | 10 | No |

UV2 stores one unique ID per triangle corner at the center of a square grid cell.
The cell index is `floor(v * grid) * grid + floor(u * grid)`, with
`grid = ceil(sqrt(corner_count))`. The near mesh has 3336 corners and far has 1224.
Vertex order after engine import is not a reliable ID; pair by these UV2 IDs.
All clips share topology within their LOD; near and far do not share topology.

Walk stride is **0.54 m per base cycle**, with 62% stance and eased foot return.
At 2.2 runtime scale the intended travel is 1.188 m per cycle. Distance-driven
phase should use this stride, while gameplay speed remains unchanged.

Both feet are fixed through windup and recovery. `windup_11` and `recovery_00`
have bit-identical positions and normals. The damage/contact event belongs to
gameplay. No mesh contains root travel or gameplay events.

Death loses support in both arms and falls into an asymmetric side-prone corpse,
with a folded arm beside the head and the other slack along the flank. The
shoulder and hip settle as the body loses its supporting arch. The runtime must
not add a second full-body topple. Ground overlap remains at most 0.011 m.
The death contact-sheet panels are centered to show the entire horizontal body;
the native integration captures are the authority for game-camera composition.

## Verification and limits

Validated: 44 exact pose names per LOD, one surface/material, no skeleton or
animations, identity transforms, finite geometry, stable UV2 corner coverage,
the attack/recovery contact match, bounds, and each GLB below 10 MB.

Authoring camera images establish shape and articulation only. Acceptance at the
normal game camera, gameplay timing, collision, and performance is a separate
runtime integration check. No gameplay numbers are changed by this package.
