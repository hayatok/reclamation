# Civilian power facility authoring

Two original visual-only models. The existing generator site remains unchanged.

- `central_station`: tall open I-section gantries, three parallel copper busbars, raised disconnect blades, ribbed porcelain supports, old switch cabinet and fragmentary brick service wall. A 1.19 m-deep front maintenance apron remains clear between the pad edge and fixed machinery; loose edge debris is outside its central width.
- `substation`: squat chamfered oil transformer tank, two broad banks of real radiator fins, three porcelain bushings, sloping cable leads, rounded conservator vessel, containment curb and repair patch.

Both models fit the inherited 4.2 × 3.5 m pad and ground radius 3 m, with ground at Godot Y=0. They use one mesh, one opaque PBR surface, full UVs and normals each. They contain no collision, navigation, animation, light or gameplay nodes. Runtime textures use the existing external salvage atlas filenames; no duplicate atlas is required for integration.

## Rebuild

From a project containing the three `assets/models/ammo_workshop_salvage_*.png` maps:

    blender --background --threads 2 --python art_source/power_facilities/source/build_power_facilities.py
    python art_source/power_facilities/source/verify_glb.py

Alternatively set `RECLAMATION_SHARED_MODELS` to the original project's assets/models directory. The generator will copy the three unchanged maps into the isolated review project when necessary. These copied files are dependencies for review, not new assets for release.

Open `source/central_station.blend` or `source/substation.blend`. Hide EXPORT_MASTER and unhide AUTHORING to edit named individual components. The existing textures are packed and use relative fallback paths. Preserve manual edits in another file before regeneration.

See the top-level `INTEGRATION.md`, `reports/geometry_report.json`, and `reports/glb_verification.json`. Native Godot screenshots and review findings are required before release; export success by itself is not visual validation.
