# Reconstructed infected integration

New reconstruction from the verified original rig and atlas; the lost earlier candidate has not been recreated byte-for-byte. The original survivor checkpoint plus independently saved desktop, worker and font work remain the base.

Normal infected now interpolate shared near/far pose meshes on the GPU. Walk phase follows actual rendered displacement, freezes while paused, and reanchors on teleport. The original immediate damage time is retained: the attack clip begins at contact and then recovers. Corpses retain the bounded cause-specific motion. Runners and armored enemies retain their existing models.

Fresh evidence: Godot4.6.3 native Compatibility rendered the same earned mission2 save at camera sizes54 and42, with69 enemies initially. After120 fixed25ms steps, all serialized checkpoint fields matched the prior build exactly (43 live enemies,315 kills). Normal camera42 frames and the supported close zoom26 show no obvious geometry explosion or detached surfaces. This sparse frame review does not establish precise foot planting or human-perceived animation quality.

Measured software renderer: llvmpipe LLVM19.1.7 at1180x737. Camera54 mean91.28→93.47ms; camera42 with building visibility active mean102.17→106.53ms, p95123.25→118.19ms. These are short single-run comparisons and do not demonstrate a performance improvement. Close zoom26 candidate mean136.38ms had47 near actors; no matched old near baseline was measured. Browser, phone and real GPU behavior remain unverified.

Pose topology/UV2 pairing, ground-safe blends and all64 shared surfaces passed. Distance/stop/pause/teleport presentation checks passed. The new near asset has more unshared vertex entries than the old welded representation; shared surface buffers are about21.94MiB plus source buffers. GPU interpolation comes with additional memory/vertex work; perceived smoothness is not yet established by the sparse frame review.

Editable generator, original inputs, manifest and structural reports are under art_source/infected_reconstruction. No gameplay cost, damage, spawn count, upgrade rule or touch input was changed. A historical dense-save fixture was rejected by the current schema; the comparison used the valid earned_critical_factory fixture instead of altering save validation.
