# Reclamation v0.10 resource icons

Original vector geometry authored for Reclamation on 2026-10-04. These are new geometric drawings, not traced or adapted from an external icon pack. The cream accent (#e5d3a4) matches the project's existing industrial UI; subdued gold and olive are supporting colors. No third-party illustrations, fonts, emoji, embedded raster images, or runtime dependencies are used in the SVGs.

## Assets

All eight assets use a 32 × 32 viewBox, transparent background, solid path geometry, and explicit colors. Filenames remain semantic and language-independent.

- `resource_food.svg`: food tin with leaf label
- `resource_salvage.svg`: crossed scrap I-beams
- `resource_parts.svg`: eight-tooth mechanical gear
- `resource_population.svg`: three-person group
- `resource_age.svg`: rising settlement skyline and development arrow
- `resource_experience.svg`: military shield with two rank chevrons
- `resource_ammo.svg`: cartridge pair
- `resource_power.svg`: lightning bolt

## Verified

- Godot 4.6.3 native `Image.load_svg_from_string`: all eight assets rasterized successfully at both 24 × 24 and 32 × 32 (16/16 passes).
- Godot headless editor import: all eight SVGs imported successfully.
- XML structure: paths only, with no text/font/emoji/image/filter/script dependencies.
- Raster checks: correct dimensions, RGBA format, nonempty geometry, transparent background, opaque foreground.
- Visual inspection of actual-size and 3× nearest-neighbor contact sheet: complete silhouettes with no garbled glyphs or clipped artwork.

Contact sheet: `qa/resource_contact_sheet.png`.
Machine-readable results: `qa/rasterization_report.json` and `qa/structure_alpha_report.json`.
Reproducible source: `tools/create_resource_icons.py`, `tools/validate_icons.gd`, `tools/contact_sheet.py`.

## Integration

Copy only `assets/ui/resource_*.svg` into the game assets directory. Godot can generate its own import metadata. Use a white texture modulate to preserve the designed colors. The icons fit 24px and 32px HUD boxes. Keep plain resource labels and tooltips next to the images for clarity; these icons do not depend on font glyph coverage. This asset task makes no edits to game runtime scripts and does not verify final HUD integration.
