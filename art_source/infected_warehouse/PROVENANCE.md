# Original infected warehouse

All new geometry and the 256 × 256 fibre texture are original procedural artwork authored for RECLAMATION. No downloaded mesh, stock texture, paid asset, franchise design or identifiable character was used. The warehouse is a new interpretation of the project's own original port-warehouse visual language. The runtime adapter reuses the project's existing `ruined_plaster.png` on architecture; that existing texture is not bundled again in this package.

Rebuild both indexed glTF binary models and the compact grayscale texture with:

    python source/build_infected_warehouse.py

Dependencies: Python 3, numpy, Pillow. Geometry does not depend on Blender, nondeterministic simulation or an external service. The deterministic generator is the editable source; the GLBs contain indices and explicit positions, normals, linear vertex colors, UV and UV2 interior-alarm mask. Each GLB has exactly two mesh primitives and two mesh nodes, one for architecture and one for infection. There are no glTF lights, animations, cameras or skins.

Install:

- `assets/infected_warehouse_alive.glb` → `assets/models/infected_warehouse_alive.glb`
- `assets/infected_warehouse_dead.glb` → `assets/models/infected_warehouse_dead.glb`
- `assets/infected_fibre.png` → `assets/materials/infected_fibre.png`, with mipmaps enabled
- `frontier_nest_visual.gd` → project root
- `infected_warehouse_material.gdshader` → project root

`create()` and `set_state(root, dead, alarm)` preserve the existing public API. Top-level `Intact` and `Rubble`, child mesh names and `frontier_art_*` metadata remain compatible. `frontier_core_material` now holds a per-instance ShaderMaterial so the alarm can affect the recessed interior only. No gameplay code is changed. No `_process`, physics, particles or new lights are added. Hidden state geometry remains resident but is not visible.

Authored hexadecimal colors are explicitly converted to linear RGB before glTF export. The runtime consumes linear vertex values and does not rely on `vertex_color_is_srgb`. Godot 4.6's official documentation states that this flag has no effect in Compatibility, the project's current native and Web renderer: https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb

Counts and bounds are recorded from exported arrays in `asset_stats.json`. These are topology/draw-surface facts, not a runtime frame-rate claim. The maximum horizontal radius is below 4.5 m, retaining clearance to the gameplay's west/south spawn centers at 6.2 m. The visible alive silhouette is approximately 5.09 m high. Recesses, folded lamellae and four tapered buttresses are deliberately broad enough for normal-camera review.
