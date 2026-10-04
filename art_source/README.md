# Editable production assets

Original Blender source, UV-atlas generators and GLB export scripts for RECLAMATION.
Blender 4.3.2 was used. Runtime models are under `assets/models/`; this directory is excluded from Godot import by `.gdignore`.

- `refuge_and_infected/`: refuge railcar and 18-bone infected, including authored idle/walk/attack/death actions and close/distant static pose baking.
- `defenses/`: salvaged gun tower and open-front ammunition workshop.

The game renders normal infected through static pose MultiMesh batches. It does not instantiate an armature per enemy. Animated rig sources remain editable here.

See `licenses/Reclamation-Hero-Models-Provenance.md` and `licenses/Reclamation-Defenses-Provenance.md`.
