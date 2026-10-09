# Original armored infected art prototype

Status: **isolated candidate, not yet accepted for production**. This package changes presentation only for ordinary armored infected. Boss art and simulation statistics are outside its scope.

The original silhouette is a burdened civilian industrial worker: broad work vest, uneven patched protective apron, one bent salvage shoulder, exposed infected jaw and hands, and heavy work boots. Its proportions, surfaces and motion were authored for this project. The owned infected atlas and existing baked-pose/corner-ID engineering convention are reused; the runner model and runner gait are not reused.

## Regenerate

Run Blender 4.3.2 in background factory mode from this directory:

    blender --background --factory-startup --threads 2 --python source/build_heavy_poses.py
    python source/validate_assets.py

The source generator is the complete editable authoring record. It writes no `.blend` file and saves no Blender UI/workspace state. The validation helper requires NumPy. Outputs are `assets/armored_baked_poses.glb`, `assets/armored_baked_poses_far.glb` and `armored_manifest.json`.

## Runtime contract

- Original geometry: 1,050 triangles per near pose and 364 per far pose; 32 shared meshes per LOD
- One material surface and one embedded copy of the owned atlas per GLB
- No runtime bones, skin, morphs, animation tracks, physics or per-actor materials
- Identity pose-node transforms, meters, Godot -Z forward
- UV2 contains unique stable corner IDs for existing GPU pose pairing/interpolation
- `idle_00..01`, loop 1.8 seconds
- `walk_00..11`, loop 1.0 second, authored 1.20 m cycle and 62.5% foot support
- Walking phase advances from measured planar displacement / 1.20 m stride, with existing actor scale accounted for
- `attack_00..07`, one-shot 0.9 second: first pose is contact, then settling recoil and grab-ready recovery; no delayed gameplay damage
- `death_00..09`, one-shot 1.2 seconds: a single authored collapse/topple, no planar root motion; use existing `CorpseMotion.baked_world` so the legacy procedural topple is not applied twice
- Idle height is approximately 1.59 m; ordinary armored simulation speed remains 1.2 m/s

## Provenance and validation

The atlas is a byte-identical copy of the project's `art_source/infected_reconstruction/assets/infected_atlas.png`; its SHA-256 is recorded in the manifest. Primitive authoring and export conventions build on the owned `art_source/runner_reconstruction/source/build_runner_poses.py`, while this package's body geometry and motion are separately authored.

Design principles consulted: Valve, *Stylization With a Purpose* (GDC 2008), silhouette-first and interior value hierarchy, pages 7 and 15–18: https://cdn.fastly.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf . No character design or art was copied.

`validation/glb_contract.json` verifies node names, budgets, one surface, identity transforms, no runtime skeleton, all unique UV2 corner IDs, finite geometry, no floor penetration, approximately 1.6 m idle scale, distinct walk poses and source/asset hashes. `validation/authoring_diagnostics.json` records foot targets, support, toe rotation and exact joint reach.

Still required before acceptance: normal-camera far-LOD silhouette review, visual planted-foot/contact review, immediate attack/contact readability, final collapsed pose settling, fresh combat comparison and measured 200-unit renderer cost. The current final death pose has a 0.96 m high lower torso while a hand reaches the floor; visual review must determine whether it needs a lower settled finish. Static validation alone does not establish art quality.
