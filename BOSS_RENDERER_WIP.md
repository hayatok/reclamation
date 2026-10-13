# Rebuilt demolition boss: limited native acceptance

The authored near/far model and 44 interpolated poses replace the generic boss at its existing scale. Windup and recovery follow actual attack clocks. Oversized tactical text no longer inherits giant-body scaling. Damage, health, range, enemy count, input and simulation rules are unchanged. This is a newly reconstructed integration, not restoration of the lost complete candidate.

Native Compatibility checks pass. The controlled same-camera 1.8-second attack has exactly equal serialized gameplay state before/after. Independent normal-camera still review accepted silhouette, strike/recovery, walking ground contact and settled death without major clipping. This does not establish animation smoothness, ordinary campaign balance or human enjoyment.

A fixed earned 94-enemy rendering comparison and a separately labelled artificial one-boss insertion measured only render-data CPU. With the boss, baseline samples were 1.112/0.965ms and candidate samples1.250/1.106ms. Drift is visible; additional CPU work is expected, and no FPS/browser-speed improvement is claimed. Real Web/Mac/phone/GPU and audible output remain unverified. See docs/boss_rebuilt_review.

Run tests/check_boss_renderer.gd with native Compatibility rendering; headless Dummy ignores instance-transform setters. Visual fixtures write to user:// and deliberately create controlled enemies. The benchmark requires RECLAMATION_BASELINE_SOURCE pointing to verified0.64 source with imported assets. An initial schema3 fixture was rejected; only the current schema4 fixture produced reported measurements. Public version stays0.64.0.
