# Production art pipeline

Blender 4.3.2 → GLB → Godot 4.6.3 Compatibility. Runtime models are in `assets/models/`; editable originals are in `art_source/`, excluded from Godot import by `.gdignore`.

## v0.9 settlement and mobile siege cart

The new original assets distinguish civilian homes, storage, food growing, survivor training and vehicle repair. The cart is a mobile improvised mortar with four wheels and two axles, rather than the temporary fixed-mortar model. These are modeled surfaces, not concept-image substitutes.

| Model | Visual size X × height × Z (metres) | LOD0 triangles | Authored components |
|---|---:|---:|---:|
| House | 3.20 × 2.7725 × 3.20 | 3,732 | 75 |
| Depot | 3.60 × 2.5716 × 3.20 | 5,020 | 94 |
| Training shelter (`barracks`) | 4.80 × 2.9275 × 4.40 | 5,392 | 86 |
| Vehicle workshop | 5.20 × 3.3574 × 4.80 | 8,336 | 125 |
| Garden | 4.00 × 1.1300 × 4.00 | 8,152 | 315 |
| Mobile siege cart | 2.6633 × 2.3399 × 3.7314 | 11,000 | 426 |

The X/Z dimensions are the art's visual envelope, not a claim that collision is embedded. All six use a ground-level origin, Godot +Y up and −Z forward, one mesh surface and one opaque atlas material. Runtime navigation, construction radii, selection, costs and combat are owned by the game. The settlement models use an original 1024² albedo/ORM/normal atlas. The cart reuses the project's original 2048² civilian-vehicle atlas. Textures are embedded in the GLBs and packed in the editable Blender scenes. Garden leaves use solid geometry, without alpha cards.

The generators also produce explicit reduced GLBs. Triangle counts for LOD1 / LOD2 are: house 1,790 / 796; depot 2,408 / 1,056; shelter 2,588 / 1,154; workshop 4,000 / 1,797; garden 3,912 / 1,532; cart 4,820 / 1,840. The game imports the LOD0 files and uses its existing Godot LOD/render pipeline; generated alternatives remain reproducible from source. A reduced mesh is not the editable original.

Cart art-space muzzle position is (0, 2.116018, −1.205950), direction (0, 0.543370, −0.839493). These are visual reference coordinates, not new ballistic rules. Wheels are static geometry; there is no wheel animation, skeleton or collision body in this source asset.

Source locations and unchanged original provenance:

- `art_source/settlement/`: five packed `.blend` files, atlas/model/portrait generators and original checking scripts. [Settlement provenance](../licenses/Reclamation-Settlement-Provenance.md).
- `art_source/siege_cart/`: packed cart, model and atlas generators, rendering/checking scripts. [Siege cart provenance](../licenses/Reclamation-Siege-Cart-Provenance.md).

## Earlier authored models

- Refuge HQ: one textured PBR surface, 13,692 triangles before generated LOD.
- Scrap tower: one surface, 8,152 triangles, two imported LOD levels.
- Ammo workshop: one surface, 10,662 triangles, three imported LOD levels.
- Supply and evacuation vehicles: one surface each, about 14,500 triangles before imported LOD; original civilian cargo/tarp silhouettes.
- Ruptured utility main and shattered asphalt obstruction: one surface each, 10,272 / 8,700 triangles.
- Normal infected: original 18-bone rig; 32 static poses, 3,337 triangles close and about 520 distant. Idle 1.6s, walk 1.2s, attack 0.8s, death 1.2s. Gameplay uses per-pose MultiMesh batches, not a Skeleton3D per enemy.

The crowd renderer reads actor state and writes render transforms. Near/far selection uses projected size with hysteresis; offscreen actors are omitted from visual batches. Far meshes omit expensive dynamic shadows; near meshes retain them.

## Editable-source preservation

Each art family retains a `source/` and `assets/` layout. The original generators and provenance records are preserved. The six new Blender files were resaved only to replace stored local image, render-output and file-browser paths with relative paths. Reopening verified unchanged object/mesh inventories, named editable components and exact packed texture bytes, with no linked Blender libraries. The source folders do not duplicate runtime GLBs, review movies, preview renders, editor caches or private QA logs.

For editing, hide the joined LOD0 mesh and reveal the `AUTHORING` collection (settlement) or `EDITABLE_COMPONENTS` collection (cart), including its object visibility. See [editable-source instructions](../art_source/README.md) before rebuilding. Provenance records describe the original art handoffs; their references to standalone review projects/reports are historical, not promises that those projects are included here. No new asset license grant is inferred from the authoring tools.

## Verification boundary

Original art checks covered GLB structure, UVs, normals/tangents, surface counts, packed textures and bounds. Headless import and startup do not prove native visual quality or frame rate. Integrated v0.9 native checks are listed in [QA_V09.md](QA_V09.md).

The 201 matching saved snapshots in [QA_V08.md](QA_V08.md) apply only to the earlier art-only integration. v0.9 intentionally changes the economy, progression and save schema; that old equality result does not apply to it. Fixed-FPS movies are offline renders, not evidence of real-time performance.

Mission machinery, survivor models, special infected and district facades retain earlier procedural artwork. Visual consistency and target-device performance remain work to assess, not a completed commercial-quality certification.
