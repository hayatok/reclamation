# Water station authoring source

New original civilian water-facility artwork for RECLAMATION. See PROVENANCE.md and the game's licenses/Water-Station-Provenance.md.

Open source/water_station.blend in Blender. Hide EXPORT_MASTER and reveal AUTHORING to edit the 156 separate components. Three texture images are packed; fallback image paths are relative. Preserve manual edits in a separate copy before running the generator.

From this directory, rebuild with Python3, Pillow, NumPy and Blender4.3.2:

    python source/create_atlas.py
    blender --background --threads 4 --python source/build_water_station.py
    python source/verify_glb.py
    blender --background --threads 2 --python source/verify_packed_sources.py

The generator writes assets/water_station.glb and an optional reduced variant. The shipped game uses assets/models/water_station.glb at the game root, with Godot-generated LODs. Copy the regenerated primary asset there after reviewing it.

The matching selection portrait is rendered from the actual game model. From the game root, run Godot with tools/render_pump_portrait.tscn; it writes assets/ui/portrait_pump.png. The preview needs a native graphics-capable Godot session. It does not modify game state or save data.

The .gdignore file prevents automatic import of authoring assets into the game. No collision or navigation data is embedded in the runtime GLB.
