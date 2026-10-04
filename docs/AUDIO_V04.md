# RECLAMATION Soundscape v0.4

52 original procedural audio assets, 138.0 seconds, 48 kHz PCM16. Combat effects are mono for centered, stable tactical readability; ambience is stereo. All source sounds peak at -3 dBFS. The suggested per-event gains are additional attenuation, not loudness-normalization targets.

## Files in this source tree
- `assets/audio/`: finalized engine WAV files
- `reclamation_audio.gd`: Godot 4.6 playback manager
- `licenses/Reclamation-Audio-Provenance.md`: original synthesis provenance

## Sound design
Rifle: fast broadband ballistic crack, low punch and delayed bolt tick, four variants. Grenade launcher: hollow low body, gas puff and breech resonance, three variants. Artillery: deeper cannon transient, pressure body and long chassis resonances, three variants. Impacts separately emphasize muted blunt flesh contact or ringing armor. Light/heavy explosions add a pressure front, turbulent noise, staggered debris and short industrial reflections. Electricity uses gated and frequency-modulated arcs with a grounded transient. No recorded human speech, voice cloning or graphic gore sounds.

Progress cues share a restrained pitched-metal vocabulary. Four kill-milestone phrases escalate only at 25/50/100/250 rather than every death. Facility startup adds a spinning machine body and ready chord. Three 24-second seamless stereo beds provide ruined industrial wind/air, generator turbine harmonics and a density-driven infected crowd. Six original inhuman growl/moan variants use raspy glottal/formant synthesis; three rubble collapses and three sweeping mass-kill payoff variants reinforce zombie-apocalypse and horde-clearing identity.

## Integration
Instantiate `preload("res://reclamation_audio.gd").new()`, add it as a child, then call:
- `play_event(name, world_pos = Vector3.ZERO, intensity = 1.0)`
- `set_power(generator_on)`
- `set_industry(number_of_active_industries)`
- `set_muted(muted)`
- `set_threat(nearby_horde_density_normalized_0_to_1)`

Call `set_muted` every time the existing audio toggle changes and after save-state restoration. `world_pos` is accepted for API compatibility but currently does not pan or attenuate; camera-aware spatial mixing can be added later. All combat variants rotate deterministically and get ±5% pitch / -1.2 to 0 dB gain variation. UI/chords preserve exact pitch.

Aliases accepted: shot→rifle; grenade_launch→grenade; mortar_launch/mortar→artillery; explosion/blast→blast_light; heavy_hit→blast_heavy; chain_hit/electric→chain; build_complete→build; ui_order→order; upgrade→level; resource_pickup→pickup; facility_powerup→power. generator_loop and industry_loop enable existing loop beds, not additional player instances. Prefer `set_power` / `set_industry` for state changes.

Use launcher cues at projectile launch, explosion cues at actual projectile impact, armor/flesh cues selectively on damage, chain on arc discharge, and combo cues only on crossed milestone thresholds. Victory/defeat each have their own 3+ second cue. Do not route every kill to an upgrade sound.

## Mix budget
- Five pools: contacts 4, weapons 8, explosions 4, tactical/UI 4, infected vocal textures 3
- Category/event cooldowns from 85 ms rifle to 1.8 seconds warning
- Warning/results protected from lower-priority replacement
- Tactical cues duck combat by 7 dB, fast attack and slower release
- Ambient starts at -30 dB; power loop -34 dB, both faded and mildly ducked
- Private mix bus hard limiter at -1 dBFS; no changes to unrelated Master bus settings
- Voice caps, low impact gain and per-event throttles are intentional in mass combat
- Mute also stops effects, preventing a stale event burst on re-enable
- Loop flags and exact 1,152,000-frame loop end are set explicitly by the manager

## Validation and limits
All 52 WAVs pass peak, DC, non-silence and clipping checks. Loop boundary deltas stay within their ordinary sample-derivative range. Runtime smoke test loads every event, submits a 3,000-request burst, verifies throttling, reserved tactical voices, ducking, loop flags, mute, aliases and private-bus cleanup. No resource leaks in final test.

No listening-capable tool was available. These files have **not** been perceptually auditioned by the assistant or a human. Numeric validation cannot establish perceived realism, comfort, balance on phone speakers or headphone fatigue. The preview is provided for that final subjective review, not as evidence of audition. Preview peaks at roughly -13.4 dBFS at gameplay reference gain; turn up playback if needed. It contains no clipping or mastering boost.

## Reproduce
With existing Python, NumPy, SciPy and ffmpeg:
1. `python source/generate_audio.py`
2. `python source/validate_audio.py`
3. `python source/make_preview.py`
4. `ffmpeg -i reclamation_sound_preview.wav -c:a libvorbis -q:a 5 reclamation_sound_preview.ogg`

Run `source/test_audio.gd` through Godot with the game as project path. Generation uses a fixed seed and no network, accounts, external samples or paid services.

## Apocalypse-specific hooks
Use infected_growl and infected_moan sparsely when threats are near or enter view; these have a dedicated three-voice cap and cooldowns. Call set_threat(0) when no nearby horde remains so the infected bed fades away. ruin_collapse suits demolition or ruined-structure destruction. kill_sweep belongs to a major area kill, chain-reaction payoff or high kill milestone, not every individual hit. The existing build/pickup cues emphasize scrap, contactors and scavenged mechanical locks.
