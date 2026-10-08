# Infected pose reconstruction, 8 October 2026

These are **newly reconstructed assets**, derived from the verified base infected
rig, mesh, atlas, and original pose function. They are not recovered revision-039
assets, and no byte identity or visual identity with that missing revision is
claimed. Nothing in the verified base or the main game candidate was edited.

## Deliverables

- `assets/infected_baked_poses.glb`: 32 near poses, 3,337 triangles and 10,011 unique
  corner vertices per pose; 14,252,768 bytes.
- `assets/infected_baked_poses_far.glb`: 32 far poses, 520 triangles and 1,560 unique
  corner vertices per pose; 2,894,240 bytes.
- `assets/infected_atlas.png`: unchanged source atlas, also embedded byte-for-byte
  in each GLB.
- `source/build_reconstructed_poses.py`: editable reconstruction generator.
- `source/infected_pose_source.blend`: editable original rig with prepared near
  and far rest meshes and the original action data. The far rest mesh is hidden
  to make inspection of the near mesh easier.
- `source/infected_civilian_original.blend` and `source/legacy_build_infected.py`:
  verbatim verified inputs, with SHA-256 hashes in the manifest.
- `infected_manifest.json`: counts, timings, original pose sample times, topology
  signatures, source hashes, output hashes, and reconstruction limitations.
- `validation/glb_contract_report.json` and `validation/godot_contract_report.json`:
  source and native import/pose-pair validation results.

Only copy the two GLBs into the game's `assets/models/` for runtime integration.
The editable source belongs in the art-source tree. Keep the reconstruction
manifest and provenance with it. Do not copy this isolated validation project's
generated `.godot` cache, engine settings, or `.import` files into the game.

## Pipeline

1. Open the verified original Blender rig. Mute its NLA tracks and clear its
   active action before direct pose evaluation.
2. Freeze near triangulation before deformation. Copy the weighted rest mesh,
   decimate the copy once at ratio 0.16, triangulate, and validate it in rest space.
   Decimation produces 13 duplicate faces, removed once here; the resulting far
   topology has 520 triangles for every pose.
3. Preserve the primary atlas UV layer and material. Assign a unique UV2 ID to
   every triangle corner. Encode cell centers in a square grid whose side is
   `ceil(sqrt(corner_count))`: 101 near, 40 far. Compensate for Blender's glTF V
   flip so imported IDs cover exactly `0..vertex_count-1`.
4. Reuse only the original generator's `pose` function against the original rig.
   The reconstruction generator extracts that function with Python's AST;
   original top-level modeling and exports are never executed.
5. Bake 2 idle, 12 walk, 8 attack and 10 death poses per LOD. Durations remain
   1.6/1.2/0.8/1.2 seconds; idle and walk loop. Idle samples original t=0.25/0.75,
   walk samples t=i/12, and death samples t=i/9. Attack starts at original t=0.5
   contact and ends at t=1.0 recovery, so timestamp zero matches the retained
   renderer's already-applied damage event.
6. Apply coordinate conversion into the geometry and floor each pose. Export
   identity object transforms, one PBR surface, no skins, no animations, and no
   Draco compression. Each LOD has identical corner topology across all poses.

## Validation performed

Blender 4.3.2 generated the final assets in 2.09 seconds wall time with peak RSS
about 304 MiB. Its optional Draco plugin reports that its shared library is
missing; Draco is explicitly disabled and neither GLB requires an extension.
There are no remaining invalid-mesh warnings in the final export.

The independent GLB check passed all 64 poses: expected names and counts,
identity transforms, one material, original embedded atlas bytes and primary
UVs, finite positions and normals, unique complete stable corner IDs, identical
triangle corner topology, and zero skeletons/animation tracks. Minimum height is
zero for both LODs. Vertex-linear interpolation cannot go below the lowest
endpoint, so all pose-pair blends remain floor-safe.

Godot 4.6.3 imported the GLBs using its default scene mesh settings, including
compression and generated LODs. The **unmodified retained pose library and
shader** successfully configured all 64 pose-pair meshes. Native checks passed
counts, complete IDs, primary UV correspondence, topology, floor safety, clip
end behavior, and every paired next-position and next-normal value. Pair target
position error was exactly zero. The imports happened to keep the same vertex
ordering across poses; a separate stress check reversed every target vertex
and remapped indices, and pairing still passed. Repacking that synthetic test
mesh's normals introduced at most 0.000119 vector error, measured separately
from pairing correctness.

Final native validation ran in 1.92 seconds wall time with approximately 102 MiB
peak RSS. Library load/configure was about 0.389 seconds in this headless test.
The final contract log contains no errors or warnings. Initial native startup
could not write its default user directories; the successful run uses writable
task-local XDG data/config/cache directories without changing HOME.

## CPU, memory and rendering implications

Unique corner IDs intentionally prevent vertex sharing. Both libraries contain
370,272 imported vertices in total. This is shared library storage, not one copy
per infected actor. Packed base surface buffers total 8,635,584 bytes (8.24 MiB);
the 64 paired surface buffers total 23,006,400 bytes (21.94 MiB), including their
retained index LODs. These measurements exclude textures, imported shadow
meshes, engine objects, transient arrays and allocator overhead. Peak RSS above
is for an isolated headless validation process, not the game's memory footprint.

Pair construction is one-time linear work across the library. Runtime actors
use the existing shared MultiMesh batches and GPU interpolation, with no
per-actor Skeleton, skinning evaluation, mesh, or material. A near base pose has
10,011 vertex entries and a far pose 1,560, so vertex work is higher than a welded
mesh at the same triangle count. The retained library accepted no automatic
near sub-LODs under its existing 0.45 triangle-ratio rule; far poses each retained
one. No performance or gameplay frame-rate claim is made.

## Known limits and next review

- The legacy walk mechanics are retained. The renderer's 1.12 m stride constant
  is preserved elsewhere; this reconstruction does not establish that the old
  foot swing visually matches that distance. Review gait/foot sliding in game.
- The reconstruction is structurally compatible with the recovered runtime,
  but still requires native visual review of silhouette, attack contact,
  transitions, corpses, and near/far appearance in the integrated game.
- The original rig proportions, material, atlas, and pose mechanics are reused;
  no art redesign or gameplay feature is included.

## Reproduce

From this directory, run these sequentially, using the shared engine slot:

```sh
blender --background --factory-startup --threads 2 --python source/build_reconstructed_poses.py
python validation/validate_glb.py
```

`validation/assets` is a relative symlink to `../assets`. Before Godot, create
writable task-local `validation/engine_home/{data,config,cache}` directories and
point XDG_DATA_HOME, XDG_CONFIG_HOME, and XDG_CACHE_HOME at their absolute paths.
Leave HOME unchanged. Then run sequentially:

```sh
godot --headless --path validation --editor --import
godot --headless --path validation --script res://validate_contract.gd
```

Inspect the JSON `passed` fields and logs as well as process exit status.
