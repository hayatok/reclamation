# Production art pipeline

Blender 4.3.2 → GLB → Godot 4.6.3 Compatibility.

## Runtime models
- Refuge HQ: one textured PBR surface, 13,692 triangles before generated LOD.
- Scrap tower: one surface, 8,152 triangles, two imported LOD levels.
- Ammo workshop: one surface, 10,662 triangles, three imported LOD levels.
- Supply and evacuation vehicles: one surface each, about14,500 triangles before imported LOD; original civilian cargo/tarp silhouettes and the existing gameplay footprint.
- Ruptured utility main and shattered asphalt obstruction: one surface each, 10,272 / 8,700 triangles, original exact blocker dimensions and imported LOD.
- Normal infected: original 18-bone rig; 32 static pose meshes, 3,337 triangles close and about520 distant. Idle1.6s, walk1.2s, attack0.8s, death1.2s. Normal gameplay uses per-pose MultiMesh batches, never a Skeleton3D per enemy.

All model origins are ground level, +Y up, facing−Z. Existing gameplay roots, navigation and footprints remain unchanged. The crowd renderer only reads actor state and writes render transforms. Near/far selection uses projected size with hysteresis; offscreen actors are omitted from visual batches. Far meshes omit expensive dynamic shadows; near meshes retain them.

## Editable sources
Each folder in `art_source/` preserves a `source/` and `assets/` layout. Run its atlas generator before the Blender export script when rebuilding from scratch. Packed `.blend` files also contain their textures. Runtime assets are intentionally separate from editable sources.

## Verification scope
Structural checks cover UVs, normals, tangents, identity pose transforms, finite bounds, material maps and mesh LOD. Native Godot previews have been inspected. The art-only integration matched the previous gameplay baseline at201 consecutive saved snapshots. A subsequent bounded crowd-separation change intentionally changes enemy paths; it is verified separately against earned campaign routes. Captured fixed-FPS movies are offline renders, not evidence of real-time performance.

HQ, two defenses, civilian vehicles, tactical street cover and the normal infected have received this authored-model pass. Mission machinery, survivors, special infected and district facades retain earlier procedural artwork. Their visual consistency remains an identifiable art gap.
