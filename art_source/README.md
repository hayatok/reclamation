# Editable production assets

Original Blender sources, UV-atlas generators and GLB export scripts for RECLAMATION. Blender 4.3.2 was used. This directory is excluded from Godot import by `.gdignore`; game runtime models are under `assets/models/`.

- `refuge_and_infected/`: refuge railcar and 18-bone infected, including idle/walk/attack/death actions and static pose baking.
- `defenses/`: salvaged gun tower and open-front ammunition workshop.
- `vehicles/`: civilian supply truck and evacuation carrier.
- `street_cover/`: ruptured water main and shattered road obstruction.
- `settlement/`: v0.9 house, depot, garden, survivor training shelter and vehicle workshop.
- `siege_cart/`: v0.9 mobile improvised mortar cart, four wheels and two axles.

Each family keeps its original `source/` scripts and packed editable `.blend` scenes alongside original atlas inputs in `assets/`. Reveal the hidden `AUTHORING` collection in settlement scenes, or `EDITABLE_COMPONENTS` in the cart/vehicle scenes, and hide the joined export master before editing individual parts. Normal infected are rendered by static-pose MultiMesh batches in game; editable rig sources remain here.

## Rebuild the new v0.9 models

Work in a copy of the relevant family folder, because generators overwrite its authoring outputs. Python 3 with Pillow and NumPy and Blender 4.3.2 are required. Create `assets`, `reports`, `previews` and `icons` output folders first. These generated reports are not part of the source archive.

For the five settlement buildings, run from the `settlement/` copy:

```sh
mkdir -p assets reports previews icons
python source/create_atlas.py
blender --background --threads 4 --python source/build_settlement.py
blender --background --threads 2 --python source/verify_packed_sources.py
```

For the cart, run from the `siege_cart/` copy:

```sh
mkdir -p assets reports previews icons
python source/create_vehicle_atlas.py
blender --background --threads 4 --python source/build_siege_cart.py
blender --background --threads 2 --python source/verify_packed.py
```

The model generators create self-contained GLBs and two reduced variants. Original render/validator scripts are retained as authoring sources; some checking/packaging scripts target the original standalone art-review project and require that harness. `package_assets.py` is that original package builder, not the game's release procedure. Do not run it as a game-release step.

The six new packed scenes use relative image/output/file-browser paths. Reopening after path cleanup verified unchanged named components, mesh inventories and packed-image bytes; no linked Blender libraries are required. Source scripts and provenance text were copied without rewriting their authorship or license statements. Runtime imports, GLB duplicates, preview renders, standalone review projects and raw QA logs are not duplicated here.

See `licenses/Reclamation-Settlement-Provenance.md`, `licenses/Reclamation-Siege-Cart-Provenance.md` and the other original provenance records under `licenses/`. Their references to standalone package reports describe the original handoffs. This source layout does not add a license grant or alter third-party terms. Model dimensions and verification boundaries are in `docs/PRODUCTION_ART.md`.
