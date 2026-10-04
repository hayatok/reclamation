# Art-direction references

The art pass applies general production principles, not copied characters or assets.

- [Valve: Dota 2 Character Art Guide](https://help.steampowered.com/en/faqs/view/0688-7692-4D5A-1935): prioritize how silhouettes and value contrast read at the actual game camera, keep areas of visual rest, and avoid letting small texture detail overwhelm recognition.
- [Godot 4.6: BaseMaterial3D](https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html): use actual mipmaps with linear/anisotropic filtering for terrain and surfaces viewed at oblique angles.
- [Godot 4.6: 3D rendering limitations](https://docs.godotengine.org/en/4.6/tutorials/3d/3d_rendering_limitations.html): alpha effects have sorting/cost limits. Battlefield smoke and blasts use bounded shared batches, while scenery fading stays selective.

The first native material pass was rejected because fine texture detail overwhelmed the playing field. The correction combines mipmap generation, lower microcontrast and larger authored ground regions. Final comparisons use the same earned checkpoint and camera as the prior version.
