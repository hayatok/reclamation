# Original articulated runner

This candidate replaces only the previous six rigid runner pieces. It is an
original mesh and original motion authored with the project's existing owned
atlas. No third-party model, copied character, per-actor rig, or runtime physics
is used. Normal infected, armored enemies, gameplay data, speed, contact timing,
projectile origins and input controls are untouched.

## Art and motion

- A narrow exposed ribcage, bunched jacket back, one long sleeve, one bare arm,
  uneven hanging hem, one exposed shin, long jaw, and low forward head distinguish
  the silhouette. The model is not a recolored copy of normal infected.
- The offline 18-bone rig articulates elbows, knees, ankles and the upper body.
  Runtime shares 28 poses per LOD: 2 idle, 12 run, 6 attack and 8 death.
- A full run cycle travels 1.72 meters. Runtime phase advances by actual rendered
  root displacement, preserving the existing 2.7 m/s gameplay speed. Foot support
  takes one third of a cycle per side; a short flight separates support legs.
- Late support rolls over the forefoot. Recovery tucks the ankle up to 40 cm,
  while unequal arm drive and clothing keep the outline off balance. This is
  offline posing; no skeleton, IK or per-enemy animation player runs in game.
- Attack pose 00 is contact because game damage already occurs at its timestamp.
  Recovery remains .8 seconds. Death remains 1.2 seconds and uses the existing
  CorpseMotion trajectory and clip-age mapping without a second procedural fall.

## Canonical deliverables

- `../../assets/models/runner_baked_poses.glb`: 28 near poses, 1,328 triangles each,
  3,984 corner vertices each; 5,462,992 bytes.
- `../../assets/models/runner_baked_poses_far.glb`: 28 far poses, 312 triangles each,
  936 corner vertices each; 1,892,692 bytes.
- `source/build_runner_poses.py` and `source/runner_gait.py`: original geometry,
  rig, pose, export and diagnostic source.
- `source/runner_original_rig.blend`: editable weighted rig saved as scene datablocks without editor UI history. See SOURCE_CLEANUP.md for the fresh-process reopen and exact content comparison.
- `assets/runner_atlas.png`: verbatim owned source atlas; its SHA is recorded.
- `runner_manifest.json`: source/asset hashes, topology and timing contracts.
- `validation/horde_integration.patch`: the small independent runner-renderer
  hook for the horde. It creates a separate child and skips rigid runner batches
  only when the new renderer has configured successfully.
- `../../runner_pose_library.gd` and `../../baked_runner_renderer.gd`: shared UV2
  pose pairing, the retained shader, distance gait and batching.

Do not copy caches, `.import` metadata, backup blends, Python bytecode, or the
redundant local exported GLBs under this directory's assets folder. Canonical
runtime files above are sufficient to rebuild imports.

## Reproduce

Use the project's Blender 4.3.2 and Godot 4.6.3 toolchain. Run one heavy process
at a time. From the project root:

    blender --background --factory-startup --threads 2 --python art_source/runner_reconstruction/source/build_runner_poses.py
    python art_source/runner_reconstruction/validation/validate_glb.py
    godot --headless --editor --import
    godot --headless --script res://tests/check_runner_art_contract.gd

Use writable task-local XDG data/config/cache directories when the environment
requires them. Do not change HOME. The isolated native art-review script is:

    godot --resolution 1180x737 --script res://tests/review_runner_asset.gd -- --out=/your/output/prefix

Before publishing a newly generated editable binary, run the scene-only cleanup
in SOURCE_CLEANUP.md into a separate output and validate its paths. The supplied
generator_public_source.patch is an optional unapplied source-save change; runtime
geometry was not regenerated during cleanup.

That script compares near/far assets, captures close poses and the actual normal
orthographic size 50 at 1180×737, then exits. It is explicitly an isolated art
preview, not an earned gameplay clip or a browser performance test.

## Verification and limits

The independent GLB check passes all 56 meshes: one opaque atlas surface,
identity transforms, no skins or animations, finite normals/positions, complete
stable UV2 corner IDs, fixed topology/UVs, and floor-safe linear blending.

Headless Godot checks pass shared pairing, normal-cache independence, correct
speed/armored classification for living and corpse dictionaries, no double draw
of rigid runners, distance gait and pause stability, immediate attack contact,
saved-start corpse placement, and no gameplay dictionary mutation.

These structural checks alone do not establish visual acceptance or browser
performance. The integrated movement pass subsequently compared two consecutive
six-second intervals of the same earned advance at normal camera size, with exact
saved-state equality. The controlled200-runner comparison and visual limits are
recorded in ../../docs/RUNNER_MODEL_WIP.md. Close-up previews were not the sole
acceptance evidence; real browser/device and melee readability remain unverified.

Far decimation is performed once before posing. It can raise the sole by a few
millimeters or require up to 1.3 cm floor correction in two push-off poses. A
linear 12-pose cycle is an approximation; turns can still scrub feet. The
asset-review scene is intentionally separate from gameplay acceptance.
