# Asset provenance and outside-pack evaluation

Checked 2026-10-04 against primary creator pages.

## Actual delivered and integrated candidate
All refuge HQ geometry, UV atlas pixels, roughness/metallic maps, sign geometry and source scripts were created specifically for this project. No external model, stock texture, photo or downloaded font was incorporated. The sign uses Blender's built-in text shape converted to geometry; no font file is redistributed. These original project assets may be included with the project's public source distribution under the project's chosen terms. This note does not relicense the user's project.

Toolchain already present: Blender 4.3.2, Godot 4.6.3, ImageMagick, Python Pillow and NumPy. No software installation, account creation or payment was needed.

## Verified outside options, not downloaded or claimed as integrated
- Quaternius Animated Zombie Pack: https://quaternius.com/packs/animatedzombie.html. Creator page identifies CC0 and two animated atlas-textured zombies in FBX/OBJ/Blend; commercial use allowed. Good donor for animation/rigging experiments, but its skinned runtime needs a deliberate near/far or baked-pose bridge to existing six-part MultiMesh batching. Do not replace thousands of instances with individual Skeleton3D and AnimationPlayer nodes. Specific clip coverage and retarget quality remain unverified because pack was not imported.
- Kenney City Kit Industrial: https://kenney.nl/assets/city-kit-industrial. Creator page explicitly CC0, 40 models. Commercial use and redistribution under CC0 are compatible with public source. Clean geometric silhouettes require heavy weathering/salvage adaptation before they fit this game; therefore not bulk-added.
- Poly Haven: https://polyhaven.com/license. Primary license confirms all asset models/textures/HDRIs CC0, including commercial use and redistribution. Suitable future plaster/concrete/rusted-metal material donor. No specific texture selected or downloaded for this prototype, so there is no implied per-file provenance. Website prose/logos/gallery examples are not CC0 and are not bundled.

All three are zero-price asset candidates; no paid expansion or third-party code was installed. License research is not a claim that their contents have been integrated or performance-tested.

## Infected addition
The infected civilian's mesh, UV atlas, 18-bone armature, idle/walk/attack/death keyframes, and 32 near/far baked pose meshes are also original project-authored assets. No external animation, scan, stock human model, Quaternius file or facial likeness was incorporated. The outside zombie pack above remained a researched alternative. The actual infected source is `source/build_infected.py` and the packed editable `source/infected_civilian.blend`.
