# RECLAMATION ruined freight yard: original source and provenance

These are new original assets authored for RECLAMATION on 2026-10-08: two crushed freight-cover silhouettes and one surviving civilian cargo-transfer gantry. They are new work for the game's established setting, not a claim of exact historical asset recovery.

All component geometry, damage profiles, composition, UV placement, freight-handling pictogram and procedural atlas pixels were authored in the included source. There are no downloaded meshes, scans, photographs, stock textures, external logos, generated-image inputs, copied products or paid assets. The project's existing original water, power and street-salvage sources were inspected for compatible component naming, material conventions and export structure. No external reference asset is distributed.

The freight covers have visibly deformed corrugated walls, sagging and missing roof sections, bent stays, inward-damaged doors and retained cargo. Muted teal and oxide variants share the same material and atlas. Their surviving low chassis preserves the existing obstacle's ground footprint while the upper silhouettes break the former row of intact rectangular roofs.

The gantry is patched civilian loading infrastructure: splayed supports, an open lattice bridge, a rolling geared winch, slack cable and hook, partially collapsed rain shelter, salvaged controls, timber pallet crate and bundled pipes. It has no military unit identity or insignia. Its geometry remains within the already blocked 4.2 by 3.5 metre site footprint.

## Included source and assets

- `source/create_freight_atlas.py`: deterministic original 1024 by 1024 albedo and ORM atlas generation, with broad weathering and padded tile borders.
- `source/build_freight_yard.py`: deterministic named-component Blender authoring and GLB export, with optional review renders.
- `source/*.blend`: editable named components and joined export masters, with both atlas images packed and relative fallback paths.
- `assets/*.glb`: one static runtime mesh and one PBR surface per model, referencing the two shared atlas PNGs beside the GLBs. No embedded duplicate texture payload, skeleton, animation, collision, script or light.
- `assets/*.png.import`: source import metadata explicitly enabling Godot mipmaps; generated editor caches are not part of the deliverable.
- `integration/freight_yard_visuals.gd`: optional visual-only integration helper. It shares the imported PBR material, uses fixed index-based cover variants, and optionally shows a two-triangle readiness lens for the game's existing reclaimed state.
- `reports/geometry_report.json` and `reports/validation_report.json`: measured geometry, bounds and independent GLB contract checks. Rendering and runtime verification must be reported separately from these file checks.

Python and Pillow produce the atlas; Blender produces the geometry and GLBs. These identify authoring dependencies, not asset authors or licensors. This file records provenance and does not establish or change a copyright license. No new CC0, MIT, Creative Commons or other blanket grant is asserted. Distribution and use remain subject to the project's applicable ownership, agreements and license terms.
