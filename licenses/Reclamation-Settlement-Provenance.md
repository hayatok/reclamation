# RECLAMATION v09: civilian settlement assets

All geometry, UV layout, procedural textures, command glyphs, model-rendered portraits, and scene code in this package are original work authored for RECLAMATION. No third-party meshes, scanned assets, stock images, logos, or external image textures are included. No generative image source was used. Blender 4.3.2 and Godot 4.6.3 were used for authoring and verification.

The modelling helpers and procedural salvage material approach adapt the project's own original `art_source/defenses/source/build_defenses.py` and `create_atlas.py`. New building geometry, silhouettes, atlas palette, garden geometry, hoist, household parts, and command glyphs were authored for this settlement set. The GLB binary contract validator adapts the project's original vehicle validator. The authoring collection retains named source components; a separate joined copy is exported.

## Models

- `house`: patched civilian timber/plaster home, domestic door and window, leaking metal roof repair, canvas porch, stove flue, stool and kitchen planter.
- `depot`: open-front timber lean-to, visibly stacked shipping crates, canvas supply sacks, water drum and handcart. Single-sloped oxide roof distinguishes it from the ammunition workshop.
- `barracks`: improvised survivor training quarters, canvas shelter, reused civilian lockers, shared map table, rolled bedding, handmade targets, tire and punching bag. It is not a professional military base.
- `vehicle_workshop`: open repair bay, broad shallow curved roof, independent engine lifting gantry, exposed rolling chassis, raised bonnet, workbench, tires and floor jack. It is not the ammunition workshop or the railcar HQ.
- `garden`: three salvaged timber raised beds, leafy food plants and fruiting vegetables, low support twine, watering can, harvest box and spade. Vegetation is solid folded mesh geometry, without alpha cards.

## Materials and mapping

One opaque material and one render surface per GLB. One original 1024×1024 atlas set provides albedo, packed ORM (occlusion=R, roughness=G, metallic=B), and tangent-space normal. Tiles deliberately repeat by material class. There are no floating labels or pixel-scale text dependencies. UVs, normals and tangents are exported. All image data is embedded in each GLB and packed into each editable Blender source.

## LODs and coordinate contract

LOD0 is the authored source mesh. Two separately exported, triangulated mesh reductions are provided per asset. Reduction is followed by atlas-cell UV clamping and snapping near-ground vertices to the ground plane. Godot also generates internal mesh LODs on normal import. Every file is static, with one mesh, one material, no armature, and no animation.

Metres, root at the construction footprint centre on the ground, Godot +Y up, -Z front. Blender authoring uses +Z up and +Y front; the glTF exporter performs axis conversion. Ground pad dimensions define each requested X/Z construction footprint. Minor raised LOD edge changes remain inside that footprint.

These are project-owned original production assets and may be edited and redistributed with RECLAMATION. Third-party tool licenses do not impose additional asset attribution. This provenance record is not a claim that external libraries or tools were themselves authored for the project.
