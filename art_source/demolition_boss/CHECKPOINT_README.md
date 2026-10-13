# Demolition boss rebuild checkpoint

Built on 2026-10-13 using unchanged retained Python generators, the retained atlas, and Blender 4.3.2. These are newly generated GLBs. Their SHA-256 hashes exactly match the retained original manifest; FAR is also byte-for-byte equal to the separately retained original file.

- NEAR: 6,392,204 bytes; SHA-256 `00fcbffc994bad1d11d35e02448273b1d5b91dd13b1c10efc90649ff1d10baae`
- FAR: 2,495,412 bytes; SHA-256 `6130fb979bd26faef5c3aa2b5473bb8313ca6e68256e0be77cefbb59ecf3bbf9`

Both LODs pass the retained validator: 44 exact poses, one surface/material, identity transforms, no skeleton/tracks, finite geometry, unique UV2 corner IDs, bounds, and exact windup_11/recovery_00 positions and normals. NEAR has 1,112 triangles/3,336 corners per pose; FAR has 408/1,224. The additional audit verifies stable semantic topology and UV0, zero degenerate triangles, and opaque material with exact retained 512 × 512 RGB atlas bytes.

See `generated/boss_manifest.json`, `review/glb_contract.json`, and `review/rebuild_audit.json`. File sizes and hashes are in `CHECKPOINT_CONTENTS.json`.

To validate the supplied assets:

```sh
python source/validate_boss_glb.py
```

To regenerate using the supplied atlas:

```sh
blender --background --factory-startup --threads 2 --python source/build_boss_poses.py
python source/validate_boss_glb.py
```

Python requires NumPy for validation. The included optional atlas/contact-sheet scripts use Pillow. The atlas generator is retained source; running it is unnecessary because the exact original atlas is supplied in `generated/`.

This asset-only checkpoint contains no `.blend`, workspace paths, game code, or runtime integration changes. Game-camera composition, gameplay, collisions, imported UV2 pairing, and performance require a separate integration check.
