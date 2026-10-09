# Bulk resource model provenance

The food, salvage, and parts meshes in `resource_visuals.gd` are original procedural source geometry authored for RECLAMATION. They use the project’s existing box, prism, quad, and triangle helpers, plus new faceted sack, bent sheet, toothed wheel, and winding geometry. No downloaded models, photographs, image-generated assets, or third-party textures are used.

- Food is a loaded pallet of provision cases and bulging sacks under a weathered partial canvas cover.
- Salvage is a strapped bundle of structural I-beams with exposed cut ends, an off-cut, and a torn corrugated sheet.
- Parts is a stripped gearbox on skids, with a large exposed toothed wheel, open access well, copper motor winding, and detached housing.

All materials are opaque, matte, vertex-coloured, and nonmetallic. Every kind has one indexed surface, cached across instances. The unchanged `add_resource(parent, kind)` entry point adds only a mesh instance. There are no collision, navigation, economy, RNG, fog, worker-access, or label changes.

`resource_visuals.measurements.json` records the measured bounds, triangle counts, cache reuse, surface count, and source SHA-256 from Godot 4.6.3 headless instantiation. All vertices fit inside the existing 1.4 m resource footprint and below 1.8 m, with ground contact at y=0. Normal-camera visual acceptance is separate from this geometry check.
