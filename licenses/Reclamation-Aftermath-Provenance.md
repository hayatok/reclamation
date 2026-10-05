# Source and provenance

This is a new original procedural presentation implemented for RECLAMATION on 2026-10-05. It does not claim to recover deleted code or assets.

- Civilian geometry and pose API: unchanged copy of the current game's `actor_visuals.gd`.
- Structure/vehicle instantiation: unchanged `structure_visuals.gd` and `water_station_visuals.gd`.
- Review-only ruined district: unchanged `world_art.gd` and its two project-owned original material textures.
- Review/runtime supply truck and review-only evacuation carrier: the existing original GLBs from `assets/models`. Editable Blender components and vehicle atlas generation remain in `art_source/vehicles/`; this candidate does not alter them.
- Review-only pump: the original `water_station.glb`. Editable source and existing provenance remain in `art_source/water_station/`. The outlet endpoint in Godot coordinates is `(-1.13, 0.71, 1.11)`. Existing basin interior spans approximately X -1.64 to +0.07, Z +1.12 to +1.77, with its stagnant surface at Y 0.318. The new water uses those authored coordinates.
- Original new source: `aftermath_scene.gd` authors crates, pails, water, narrow window inserts, resident silhouettes and two lamps directly as Godot geometry. `review.gd` and `tests/smoke_aftermath.gd` are new review support.

No third-party asset, new font, external texture, downloaded sound, copied artist design or generated raster artwork is included. Existing project authorship and provenance are preserved; this document does not invent or expand a license grant.
