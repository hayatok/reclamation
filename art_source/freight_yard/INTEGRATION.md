# Freight-yard art integration contract

This directory is isolated authoring output. It does not modify the validated source or change gameplay. Copy the three GLBs, both PNGs, and both `.png.import` metadata files from `assets` into the target project's `assets/models` (seven files total). Keep the editable source and provenance under `art_source/freight_yard`.

## Cover replacement

Both cover GLBs use the same standard ground-centred dimensions: length X = 6 m, height Y <= 1.3 m, width Z = 2.5 m. The chassis reaches the exact X/Z boundary; all deformed roof, door and debris geometry remains inside. Origin is on the ground. Existing tactical cover lengths, widths, positions, heights, blocker metadata and collisions must be retained.

Preload `freight_yard_visuals.gd`, then replace only `_freight`'s visual body with `FreightYardVisuals.add_cover(self, p, size, index)`. The helper mirrors the existing `_cover_model` length/width orientation convention. Cover variation is deterministic by index, with no runtime random calls. The eight existing blockers are still created by the existing `_add_collision` path.

## Cargo-transfer landmark

For existing `add_site(parent, "rail_depot")`, use `FreightYardVisuals.add_to(parent)` and return true. Keep site world position (-17, 0, 0), navigation half-extents (2.1, 1.75), interaction rules, labels and label height 4.3 m unchanged. The static asset stays below 3.4 m and inside X +/-2.1, Z +/-1.75 m. The mesh contains empty-looking areas beneath the bridge but the full existing site remains a blocker; the apron makes that footprint legible.

Optional: find `FreightTransferVisual` and forward existing reclaimed state to `set_reclaimed`. This switches a small green readiness lens over the amber cabinet lens. It adds two triangles and one unshadowed, unlit material only when on; it creates no Light3D or gameplay state. Omit this for strict one-surface landmark rendering.

## Materials and import

The three GLBs refer to exactly the same original `freight_yard_albedo.png` and `freight_yard_orm.png`, each 1024px. Import the albedo as colour and ORM as data, with mipmaps enabled. The supplied `.png.import` source metadata explicitly sets `mipmaps/generate=true`; this is required because Godot's initial external-PNG import otherwise disables mipmaps. GLB sampler minification is LINEAR_MIPMAP_LINEAR. The helper also selects Godot anisotropic mipmapped filtering and reuses the first imported PBR material for every instance; no per-cover material copies or shader updates are required.

Run the target project's normal editor import before runtime checks. Verify the imported PNG `.import` entries have `mipmaps/generate=true`, the GLB scenes have one MeshInstance3D/one surface each, and the shared material uses the right base-color and roughness/metallic maps. Do not copy generated import caches into source.

## Required runtime review

1. Capture M2 at the same camera and state as the baseline screenshot, including normal RTS zoom. Check the roof silhouettes and gantry remain identifiable without masking units, route arrows, crossing pads, labels or work edges.
2. Verify all eight original cover blocker positions/sizes and the rail-depot navigation bounds are unchanged. Recheck friendly/enemy passage through the three crossings and workers approaching the depot.
3. Compare draw/primitive counts and performance in the same scene. File geometry checks do not establish runtime performance or gameplay success.
4. Review optional readiness cue before and after reclamation if enabled.

## Regeneration

Run `python source/create_freight_atlas.py`, then `blender --background --threads 2 --python source/build_freight_yard.py`. Append `-- --render` for optional CPU review PNGs. Finally run `python source/verify_freight_glb.py`. Regeneration replaces generated GLBs and Blender source masters; preserve manual edits separately first.
