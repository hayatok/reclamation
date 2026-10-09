# Ordinary armored infected: model and movement

The old ordinary armored enemy used six rigid parts with straight whole-leg swings driven by elapsed time. This change supplies an original broad industrial-worker protective silhouette, split apron, asymmetrical damaged shoulders, articulated knees/ankles and walking phase driven by actual displacement. The final near/far meshes contain 1,094 / 364 triangles per pose, 32 shared poses each, one owned atlas and no runtime skeletons. Both LODs cast shadows.

Only ordinary armored enemies change. Bosses retain their old model and windup; a cosmetic boss flag now survives into corpse records. Existing1.2m/s speed, HP, armor, attack timing, damage, spawn counts and CorpseMotion trajectories are unchanged. The first attack pose is contact, followed by recovery; it does not move damage into an invented anticipation period.

## Visual evidence and scope

[Before](evidence/armored_motion/before.mp4) / [after](evidence/armored_motion/after.mp4) use the same camera50 and controlled fresh M1 scene. Three armored enemies were deliberately placed on verified traversable approaches; this is not earned campaign footage. Their subsequent movement, HQ attacks and two deaths use the actual game. All300 recorded simulation samples match across the old and corrected model: enemy positions/HP/contact times, guard positions/HP, ammo, kills and corpse counts. The first hit is at5.8s; deaths at7.6 and9.85s.

Independent sampled-frame review accepted a limited improvement: a broad readable armored upper body, more coherent separated legs, and a low fallen corpse. The initial thin silhouette and hands-supported forward-fold death were rejected, then corrected. The [pose view](evidence/armored_motion/poses.png) shows the old model at left and revised walk/contact/death at right. It is an enlarged inspection, not normal-camera proof by itself.

The paired battle recording retained HQ inspection from scene setup, so its name overlaps late contact. The game already shows building names only when selected/hovered; this was not a game UI bug. A short [supplemental contact recording](evidence/armored_motion/contact.mp4) uses the actual select-all-combat command to clear inspection. Its 160 simulation samples still match the corresponding baseline. The corrected sampled-frame review sees a clearly low corpse and changing contact/recovery poses, but overlapping attackers make individual strikes subtle at camera 50. Neither sampled images nor offline30fps encoding prove continuous runtime smoothness, precise visual foot planting or human gameplay quality.

The first test setup placed enemies inside central blocked cells and was discarded for movement comparison. The correction verified open spawn cells and approach routes; no game navigation or difficulty was changed to make the test succeed.

## Measured cost

In a controlled200-actor, camera50,1180×737 llvmpipe workload with both asset sets already loaded, mean native frame time was64.57ms old /58.78ms new. Renderer update CPU increased2.47→3.36ms, and draw calls rose9→about24.2. New per-round p95 frame times78.14/76.60ms did not consistently improve over77.75/68.22ms. This is an art change with a CPU/draw-call cost, not a general FPS improvement. Both new LODs cast body shadows; old rendering casts the torso only. No enemy count was reduced. Real GPU/Web/Mac/phone and runtime loading/memory effects remain unverified. Raw records are in [performance evidence](evidence/armored_motion/performance.json).

Focused engine contracts verify shared pose geometry/UV pairing, ordinary-versus-boss routing including corpses, fallback, pause and displacement clocks, immediate contact, shadows, expiry and unchanged gameplay dictionaries. The existing runner contract also passes. Native cloud audio falls back to Dummy; rapid headless shutdown may report a generic ObjectDB warning. No audio audition claim.

## Editable source

art_source/armored_reconstruction contains the original offline Blender generator, motion source, owned atlas, manifest and validation scripts. Runtime GLBs are stored once in assets/models. The generator rebuilds the full rig without retaining Blender UI history.

Design reference: Valve [Stylization with a Purpose](https://cdn.fastly.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf), GDC2008 pp7/15–18, for silhouette and visual hierarchy. No character art was copied. Static source validation alone is not art acceptance.
