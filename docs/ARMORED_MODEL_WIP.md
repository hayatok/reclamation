# Ordinary armored infected: authored model and movement (unaccepted)

This isolated art change addresses the remaining rigid six-part armored actor. It uses an original industrial-worker silhouette, asymmetric damaged shoulder armor, split protective apron, articulated knees/ankles and displacement-driven weighted gait. Shared near/far poses use one owned atlas and no runtime skeletons. Current asset budgets are 1,050 / 364 triangles per pose, 32 poses per LOD. Both LODs retain shadows.

Only ordinary armored enemies use the candidate. Bosses retain the old model and windup; their cosmetic identity now survives into corpse records. Existing speed1.2 m/s, HP, attack timing, damage, enemy counts and CorpseMotion trajectories remain unchanged. This is not a new enemy type or balance change.

Status: source and mesh contracts are prepared; normal-camera appearance, contact/death clarity, controlled combat equality and renderer cost have not been accepted. The first export's stale far-idle rig state and missing embedded atlas were caught and corrected before integration. The final death silhouette still needs direct visual inspection. No current earned armored encounter is claimed from obsolete fixtures.

Source: art_source/armored_reconstruction. Run its offline Blender generator to reproduce assets; copy generated armored_baked_poses*.glb to assets/models. Runtime assets are stored once there. Full source rig is generated, rather than storing Blender UI history.

Reference: Valve's GDC 2008 [Stylization with a Purpose](https://cdn.fastly.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf), pages7 and15–18, emphasizes class silhouette, body proportions and a visual hierarchy. This candidate uses original art; the reference is design guidance, not proof of quality.
