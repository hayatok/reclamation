# RECLAMATION original survivor vehicles

Created specifically for RECLAMATION in Blender 4.3.2. No downloaded model, stock texture, game-ripped asset, real vehicle brand, military insignia, or third-party image is incorporated.

## Deliverables

- `assets/supply_truck.glb` — patched civilian open-bed supply truck, with roof bedding, visible water containers and crates, tied canvas cargo, stamped wheels and hand-repaired cab.
- `assets/evacuation_carrier.glb` — converted civilian evacuation carrier, with cream/red panel body, arched canvas roof, passenger windows, luggage, repaired doors and rear boarding step.
- `_lod1.glb`, `_lod2.glb` variants — deliberately reduced meshes, preserving material atlas and silhouette. Godot also generates imported mesh LODs using the normal importer defaults.
- `source/*.blend` — packed editable source; `EDITABLE_COMPONENTS` collection is hidden by default, while one combined export master is visible. Unhide that collection, clear its object hide state (Alt-H in the viewport), and hide the master to edit individual modeled parts.
- `source/build_vehicles.py` — deterministic original mesh authoring, UV mapping, material wiring and GLB export.
- `source/create_vehicle_atlas.py` — deterministic original raster textures (2048² albedo, packed ORM, tangent-space normal).
- `source/render_vehicles.py` — repeatable non-interactive Blender art-review renders.
- `review.tscn`, `review.gd`, `project.godot` — isolated native Godot art-review harness. No game source is changed.
- `validate_assets.gd` — headless structural Godot import/mesh/material/bounds validation.

## Geometry and integration contract

Each exported vehicle has one mesh and one material surface. Opaque atlas glass intentionally avoids extra transparent passes and sorting artifacts. Text, panel patches, grille bars, fabric hems, fasteners, wheel tread and cargo belong to that one joined surface.

Authored Blender +Y forward converts to Godot −Z forward. Origin remains at the existing actor ground/frame origin. Envelope is contained in x ±0.925 m, y 0.03–2.06 m, z −1.90–1.575 m. This preserves the original StructureVisuals truck/convoy footprint and maximum pipe height. The new meshes are visual replacements only, with no collision, scripts, animations or gameplay effects.

Both vehicles reference the same original raster atlas. The embedded texture bytes are identical and can be remapped to shared Godot imported textures/materials if desired during integration. The individual GLBs remain self-contained.

## Provenance and permitted use

Geometry, UVs, code, markings and raster/PBR art in this folder were authored for this project. Blender's bundled Bfont is used only to generate the short original model markings. No brand identity or copied vehicle blueprint is used. These project-created assets may be used, edited, distributed and commercialized with RECLAMATION, with no external stock-asset attribution or licensing fee.

## Reproduce

    python source/create_vehicle_atlas.py
    blender --background --threads 4 --python source/build_vehicles.py
    blender --background --threads 4 --python source/render_vehicles.py
    ./run_headless_checks.sh

For native review, open `project.godot` in Godot or run the project normally. Press 1/2/3 for explicit LODs, Space for turntable rotation, wheel for zoom. Adding `-- --capture` saves a native screenshot then exits. GUI review/capture must be performed only through the parent's authorized GUI workflow.

## Verification scope

See `reports/asset_stats.json` and `reports/godot_validation.json` for measured mesh counts and structural checks. Blender background renders are an art check, not a claim of native Godot GUI verification. Native GUI review is reserved for the parent/integration task.

The headless check wrapper keeps runtime data/config/cache in the project-owned `.runtime` directory, avoiding platform-home permissions. All six final GLBs passed both direct binary-contract checks and Godot 4.6.3 import/structural validation. The native review harness also passed a headless startup smoke check. Four Blender front/rear renders were visually inspected; native GUI rendering remains unverified here.
