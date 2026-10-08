Authoring-stage measurements below; integrated game review is in [SUPPORT_GAIT.md](../../docs/SUPPORT_GAIT.md).

# Infected support-gait trial

One isolated offline animation correction. No game source, runtime stride, renderer, movement speed, or damage timing was edited.

## What changed

- The left shoe is flat and load-bearing from phase 0 to 7/12; the right supports from 1/2 to 1. The overlap is a short double-support transfer.
- During either stance the entire shoe moves backward relative to the actor at exactly 1.12 m per normalized cycle. This cancels the unchanged straight-line root travel.
- Recovery uses a cubic longitudinal path with stance-matching endpoint tangents. Left recovery is higher (9 cm authored maximum); right recovery stays low (2.8 cm) and droops slightly, retaining an unequal infected shuffle.
- Offline two-bone posing bends the knees forward and slightly outward. The pelvis is lowered 9 cm with a 1.2 cm sway to make the fixed-stride support positions reachable. Legacy hunch, head motion, shoulders, and unequal arms remain inherited.
- The rig, mesh parts, materials, original atlas, triangle topology and UV2 correspondence are preserved. Only walk posing is reauthored. Nothing is solved at runtime.

## Direct measurements

Measurements read the actual before/after GLBs, pair corners by stable UV2 IDs, reproduce the renderer’s linear pose interpolation, and add the unchanged 1.12 m/cycle forward root travel. The reported horizontal path follows the velocity of the same material sole corner; it does not confuse a changing minimum-height identity with foot motion. 12,000 phase samples are used per cycle.

| LOD / test | Before shoe path | After shoe path | Root travel |
| --- | ---: | ---: | ---: |
| near / same old phase 0.125–0.375 | 28.1857 cm | 0.0000108 cm | 28.00 cm |
| near / left authored stance 0–7/12 | 75.9418 cm | 0.0000239 cm | 65.33 cm |
| near / right authored stance 1/2–1 | 59.5120 cm | 0.0000150 cm | 56.00 cm |
| far / same old phase 0.125–0.375 | 28.2348 cm | 0.0000089 cm | 28.00 cm |
| far / left authored stance 0–7/12 | 76.1108 cm | 0.0000221 cm | 65.33 cm |
| far / right authored stance 1/2–1 | 59.4930 cm | 0.0000194 cm | 56.00 cm |

The comparison also contains the unchanged strict lower-shoe geometric proxy, a separate 1-micron tie-tolerance result, 2/5/10/20 mm contact-threshold sensitivity, and all 12 pose segments. Authored stance timing is not substituted for the baseline test.

| Near / threshold | Before cycle shoe path | After cycle shoe path |
| --- | ---: | ---: |
| L, shoe height ≤ 2 mm | 38.01 cm | 1.49 cm |
| R, shoe height ≤ 2 mm | 115.55 cm | 4.75 cm |
| L, shoe height ≤ 20 mm | 71.43 cm | 14.98 cm |
| R, shoe height ≤ 20 mm | 115.55 cm | 55.13 cm |

The larger 20 mm totals intentionally include low moving recovery, especially on the right. Grounded stance is materially planted; the result does not claim all near-ground motion vanished.

## Structural and non-walk checks

- near: 32 named poses, 3337 triangles and 10011 unique UV2 corners per pose; one unchanged material and atlas; identity object transforms; no runtime skeleton or animation.
- near: all UVs and triangle correspondence exactly match the frozen v0.40 assets. All 20 non-walk pose attributes bitwise identical: False. Maximum absolute differences: {'POSITION': 4.76837158203125e-07, 'NORMAL': 0.0001347064971923828, 'TEXCOORD_0': 0.0, 'TEXCOORD_1': 0.0}.
- near: finite positions, normals and UVs; unit normals; no below-ground vertices at endpoints or any linear interpolation between them. Output SHA256: `d016255bc0ef4677f74e2a7b92355eaa5d7704ebaa23b86953ded48fb7c68a7a`.
- far: 32 named poses, 520 triangles and 1560 unique UV2 corners per pose; one unchanged material and atlas; identity object transforms; no runtime skeleton or animation.
- far: all UVs and triangle correspondence exactly match the frozen v0.40 assets. All 20 non-walk pose attributes bitwise identical: False. Maximum absolute differences: {'POSITION': 4.76837158203125e-07, 'NORMAL': 9.999377653002739e-05, 'TEXCOORD_0': 0.0, 'TEXCOORD_1': 0.0}.
- far: finite positions, normals and UVs; unit normals; no below-ground vertices at endpoints or any linear interpolation between them. Output SHA256: `b25d21bc7b0a2659911aecaf10d0a929bd7d8434ab58f240e515089c9349e348`.

## Files and reproduction

- `source/support_gait.py`: editable support/recovery trajectories and offline leg solver.
- `source/build_reconstructed_poses.py`: bake/export generator; retains the original idle, attack and death pose-time policy.
- `source/infected_civilian_original.blend` and `source/legacy_build_infected.py`: copied immutable inputs.
- `source/infected_pose_source.blend`: packed editable rig/rest-mesh checkpoint.
- `assets/infected_baked_poses.glb` and `assets/infected_baked_poses_far.glb`: integration candidates.
- `validation/support_gait_comparison.json`: direct before/after foot measurements and non-walk comparison.
- `validation/glb_contract_report.json`: export, topology, finite-value and ground checks.
- `validation/authoring_diagnostics.json`: sampled ankle targets, leg reach and solver error.
- `validation/first_bake/`: preserved first bake and matching generator/report before the per-pose scale reset.

From this trial directory:

```sh
blender --background --factory-startup --python source/build_reconstructed_poses.py
python validation/validate_glb.py
python validation/compare_support_gait.py --baseline /path/to/v0.40-source
```

## Limits and visual gate

- The principal remaining gate is native normal-RTS-camera motion review: foot contact numbers alone cannot establish that the weight transfer looks coherent or that the changed pelvis height is preferable.
- Contact is inferred geometrically. No center-of-mass, force, collision or balance simulation is claimed; both shoes can be low during transfer.
- Straight travel at unit actor scale is measured. Turning can still scrub soles. Actor scaling scales distances.
- Twelve baked poses still use piecewise-linear interpolation. Recovery and contact transitions therefore retain finite near-ground movement, especially the intended low right shuffle.
- Left authored 9 cm clearance peaks at a phase between baked samples; the shipped sampled maximum is lower. The JSON reports actual interpolated clearance.
- The 9 cm pelvis drop is a deliberate reachability tradeoff and a visible walk-pose change. Silhouette geometry is unchanged, but walk posture is not identical.
- No publication, game integration or visual acceptance is implied by this isolated candidate.
