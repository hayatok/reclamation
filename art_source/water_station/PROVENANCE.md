# RECLAMATION water booster station: source and provenance

This is a new original asset authored for RECLAMATION on 2026-10-05. It rebuilds a missing later-art role; it is not represented as an exact recovered historical model.

The station geometry, component layout, UV mapping, procedural material patterns, drop pictogram and pressure dial were authored for this pass. There are no downloaded meshes, scans, photographs, stock textures, external logos or generative-image inputs. The modelling helpers and atlas approach follow the project's existing original settlement and street-salvage source, inspected to maintain its visual and technical direction. Blender 4.3.2 exported the GLBs; Godot 4.6.3 imported and verified them. Python, Pillow and NumPy generate the texture atlas.

The design is a deteriorated civilian utility installation: pressure vessel, centrifugal pump and finned motor, cast unions, red manual valve, patched pipework, broken masonry service enclosure, rain awning, electrical cabinet, collecting basin, salvaged grating, hose and a little masonry debris. Its weathered teal, grey, clay, oxide and cream palette is intended to read beside the project's civilian scavenger assets.

## Included authoring and runtime material

- `source/create_atlas.py`: deterministic original albedo, roughness/metallic and normal atlas generator.
- `source/build_water_station.py`: deterministic named-component modelling and GLB export generator, with an optional CPU render.
- `source/water_station.blend`: 156 editable named source components and a joined export master; three images are packed, and their fallback paths are relative.
- `assets/water_station.glb`: 7,912 triangles, one mesh, one surface, one PBR material, three embedded 1024 × 1024 image maps.
- `assets/water_station_lod1.glb`: 3,796-triangle optional explicit reduction, also self-contained. The primary GLB receives Godot's internal generated LODs on normal import.
- `review/`: comparison scene and source, using the project's current procedural pump as the baseline. The baseline's existing source and material are copied only to make the local comparison reproducible; they are not newly authored station assets.

This file records provenance and does not establish or change a copyright license. No new CC0, MIT, Creative Commons or other blanket grant is asserted. Distribution and use remain subject to the project's applicable ownership, agreements and license terms. Tool names above identify authoring dependencies, not asset authors or licensors.
