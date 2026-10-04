# Original asset provenance: RECLAMATION Mobile Siege Cart

## Authorship and sources

Created for the current RECLAMATION project as an original mesh asset. All cart geometry, its arrangement, silhouettes, mechanical-looking details, UV placement, and renders were authored procedurally in Blender for this handoff. The asset is fictional game artwork and does not reproduce a particular commercial vehicle or weapon model.

The single PBR material and fabrication helper methods reuse the project's own original vehicle artwork:

- `reclamation_game/art_source/vehicles/source/build_vehicles.py`: primitive, beam, plate, ring and atlas-UV fabrication helpers
- `reclamation_game/art_source/vehicles/source/create_vehicle_atlas.py`: original deterministic 16-tile civilian vehicle atlas generator (seed 809)
- `reclamation_game/art_source/vehicles/assets/survivor_vehicle_atlas.png`
- `reclamation_game/art_source/vehicles/assets/survivor_vehicle_normal.png`
- `reclamation_game/art_source/vehicles/assets/survivor_vehicle_orm.png`

Those source textures and their generator are included. They were produced from original procedural raster/noise operations, with no downloaded images, scanned materials, or third-party raster inputs. The new cart uses seed 910 for reproducible authoring. The defense assets were inspected for project conventions; no third-party geometry was introduced.

## Software and services

- Blender 4.3.2: original mesh fabrication, UV mapping, packed editable file, glTF exports, Cycles review renders
- Godot 4.6.3: import/instantiate checks and isolated review-scene smoke test
- Python / Pillow / NumPy: atlas generation, image checks, packaging, hashes

No paid assets, paid asset services, external model download, trademarked insignia, professional army branding, or image-generation service was used. All work was done in the cloud workspace. Blender/Godot licenses govern those authoring programs, not ownership of the newly generated original cart mesh.

## Deliverable source integrity

The `.blend` includes 426 individually editable components plus the joined 11,000-triangle export mesh. Its three texture images are packed. There are no linked Blender libraries. Separate lower-density exports are produced from the joined master; the authored component collection remains available in the source. The portrait and both preview images render the real LOD0 source model.

See `SHA256SUMS.txt`, `manifest.json`, and the passed checks in `reports/`.
