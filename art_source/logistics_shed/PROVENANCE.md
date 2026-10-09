# Reclaimed logistics shed

Two original civilian warehouse models for RECLAMATION: a damaged abandoned shell and its repaired resource depot. Geometry, atlas UV layouts, and cargo pictogram were authored specifically for this game. No purchased, downloaded, branded, or third-party model content is used.

The three unchanged `barracks_settlement_*.png` maps are the project's existing original settlement atlas. Both GLBs refer to those same external filenames, allowing integration beside the existing atlas without adding another texture set. This is a file-reference contract; runtime texture allocation is to be checked in the engine.

The model pair retains a 3.6 × 3.2 metre ground footprint and forward −Z orientation. The shed has through-loading bays so the repaired storage use is visible from the normal +X/+Z gameplay camera. The abandoned roof opening is missing geometry; its material remains opaque. Both versions export one indexed mesh, one surface, and one material.

The included generator reconstructs editable Blender files with original components in a hidden EDITABLE collection and a joined export object. Generated packed .blend files are not bundled in this source checkpoint.

Within the game repository, the atlas directory may be passed explicitly, for example from the repository root:

    blender --background --threads 2 --python art_source/logistics_shed/source/build_logistics_shed.py -- --atlas-dir assets/models --output-dir art_source/logistics_shed
    python art_source/logistics_shed/source/validate_assets.py --atlas-dir assets/models

Integration uses the already present `assets/models/barracks_settlement_albedo.png`, `assets/models/barracks_settlement_normal.png`, and `assets/models/barracks_settlement_orm.png`. Copy the two generated GLBs beside those files; do not make another texture set. The atlas remains at its existing runtime paths and is not duplicated here.

The generator produces the models, isolated transparent review renders, and a matching 256 px `portrait_depot.png`. Isolated renders are visual review aids; actual gameplay camera validation belongs in the game.

No navigation, collision, game rules, or executable game files are included or changed by this art package.
