class_name ReclamationAudio
extends Node
## Original RECLAMATION soundscape; all assets are preloaded once.
## Separate tactical pool prevents combat from starving warnings and victory cues.
const ROOT_PATH := "res://assets/audio/"
const EVENTS := {
 "infected_growl": ["infected_growl",3,-20.0,1.4,2,4],
 "infected_moan": ["infected_moan",3,-23.0,2.2,2,4],
 "ruin_collapse": ["ruin_collapse",3,-16.0,0.55,3,2],
 "kill_sweep": ["kill_sweep",3,-12.0,0.65,4,3],
 "rifle": ["rifle",4,-15.0,0.085,2,1],
 "grenade": ["grenade",3,-11.0,0.16,2,1],
 "artillery": ["artillery",3,-10.0,0.25,2,1],
 "impact_flesh": ["impact_flesh",3,-22.0,0.12,1,0],
 "impact_armor": ["impact_armor",3,-20.0,0.12,1,0],
 "blast_light": ["blast_light",3,-13.0,0.16,3,2],
 "blast_heavy": ["blast_heavy",3,-10.0,0.35,3,2],
 "chain": ["chain",3,-16.0,0.10,2,1],
 "order": ["order",1,-16.0,0.08,4,3],
 "build": ["build",1,-13.0,0.20,4,3],
 "pickup": ["pickup",1,-19.0,0.22,3,3],
 "power": ["power",1,-12.0,0.60,5,3],
 "level": ["level",1,-12.0,0.35,5,3],
 "warning": ["warning",1,-9.0,1.80,6,3],
 "combo_25": ["combo_25",1,-15.0,0.80,4,3],
 "combo_50": ["combo_50",1,-15.0,0.80,4,3],
 "combo_100": ["combo_100",1,-15.0,0.80,4,3],
 "combo_250": ["combo_250",1,-15.0,0.80,4,3],
 "victory": ["victory",1,-9.0,2.0,7,3],
 "defeat": ["defeat",1,-10.0,2.0,7,3],
}
const ALIASES := {
 "shot":"rifle", "grenade_launch":"grenade", "mortar_launch":"artillery",
 "mortar":"artillery", "explosion":"blast_light", "blast":"blast_light",
 "heavy_hit":"blast_heavy", "chain_hit":"chain", "electric":"chain",
 "build_complete":"build", "ui_order":"order", "upgrade":"level",
 "resource_pickup":"pickup", "facility_powerup":"power",
}
var streams: Dictionary = {}
var pools: Array = []
var last_play: Dictionary = {}
var rotations: Dictionary = {}
var beds: Array[AudioStreamPlayer] = []
var power_active := false
var industry_count := 0
var threat := 0.0
var muted := false
var duck_until := 0.0
var random := RandomNumberGenerator.new()
var bus_names: Array[String] = []
var played_count := 0
var throttled_count := 0

func _ready() -> void:
 random.seed = 41004
 # Instance-specific buses avoid muting unrelated game/editor audio.
 var suffix := str(get_instance_id())
 var mix_bus := "ReclamationMix" + suffix
 _add_bus(mix_bus, "Master")
 var limiter := AudioEffectHardLimiter.new()
 limiter.ceiling_db = -1.0
 limiter.pre_gain_db = 0.0
 limiter.release = 0.12
 AudioServer.add_bus_effect(AudioServer.get_bus_index(mix_bus), limiter)
 for label in ["Combat", "Tactical", "Ambient"]:
  _add_bus("Reclamation" + label + suffix, mix_bus)
 for event in EVENTS:
  var data: Array = EVENTS[event]
  var choices: Array[AudioStream] = []
  for i in int(data[1]):
   var file: String = data[0] + ("_%02d" % (i + 1) if int(data[1]) > 1 else "")
   var stream := load(ROOT_PATH + file + ".wav") as AudioStream
   if stream != null: choices.append(stream)
  streams[event] = choices
 # Four categories: contact, weapon, explosion, protected tactical.
 # Per-category caps avoid 100 zombies producing 100 simultaneous impacts.
 for count in [4,8,4,4,3]:
  var pool: Array[AudioStreamPlayer] = []
  var pool_id: int = pools.size()
  for i in count:
   var p := AudioStreamPlayer.new()
   p.bus = bus_names[2] if pool_id == 3 else bus_names[1]
   p.set_meta("priority", 0)
   p.set_meta("started", -1.0)
   add_child(p)
   pool.append(p)
  pools.append(pool)
 for file in ["ambient_industrial", "ambient_power", "ambient_infected"]:
  var stream := (load(ROOT_PATH + file + ".wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
  stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
  stream.loop_begin = 0
  stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
  var p := AudioStreamPlayer.new()
  p.bus = bus_names[3]
  p.stream = stream
  p.volume_db = -60.0
  add_child(p)
  beds.append(p)
  p.play()
 set_muted(muted)

func _add_bus(label: String, send: String) -> void:
 AudioServer.add_bus()
 var index := AudioServer.bus_count - 1
 AudioServer.set_bus_name(index, label)
 AudioServer.set_bus_send(index, send)
 bus_names.append(label)

func play_event(name: String, _world_pos: Vector3 = Vector3.ZERO, intensity: float = 1.0) -> void:
 if muted or pools.is_empty(): return
 name = ALIASES.get(name, name)
 if name == "generator_loop":
  set_power(true)
  return
 if name == "industry_loop":
  set_industry(1)
  return
 if not EVENTS.has(name): return
 var data: Array = EVENTS[name]
 var now := Time.get_ticks_msec() / 1000.0
 if now - float(last_play.get(name, -99.0)) < float(data[3]):
  throttled_count += 1
  return
 var choices: Array = streams.get(name, [])
 if choices.is_empty(): return
 var pool: Array = pools[int(data[5])]
 var player: AudioStreamPlayer = null
 for p: AudioStreamPlayer in pool:
  if not p.playing:
   player = p
   break
 if player == null:
  # Never cut off a higher-priority warning/result for a click or kill cue.
  var oldest := now + 1.0
  for p: AudioStreamPlayer in pool:
   if int(p.get_meta("priority")) <= int(data[4]) and float(p.get_meta("started")) < oldest:
    oldest = float(p.get_meta("started"))
    player = p
 if player == null:
  throttled_count += 1
  return
 last_play[name] = now
 var variant := int(rotations.get(name, 0)) % choices.size()
 rotations[name] = variant + 1
 player.stream = choices[variant]
 var organic: bool = int(data[5]) != 3
 player.pitch_scale = random.randf_range(0.95, 1.05) if organic else 1.0
 player.volume_db = float(data[2]) + linear_to_db(clampf(intensity, 0.35, 1.4)) + (random.randf_range(-1.2,0.0) if organic else 0.0)
 player.set_meta("priority", int(data[4]))
 player.set_meta("started", now)
 player.play()
 played_count += 1
 if int(data[4]) >= 5:
  duck_until = maxf(duck_until, now + (2.8 if int(data[4]) == 7 else 0.95))

func set_power(active: bool) -> void:
 power_active = active

func set_industry(active_count: int) -> void:
 industry_count = maxi(0, active_count)

func set_threat(amount: float) -> void:
 threat = clampf(amount, 0.0, 1.0)

func set_muted(value: bool) -> void:
 muted = value
 if not bus_names.is_empty():
  var index := AudioServer.get_bus_index(bus_names[0])
  if index >= 0: AudioServer.set_bus_mute(index, value)
 # Stops queued feedback from bursting out when sound is re-enabled.
 if value:
  for pool: Array in pools:
   for p: AudioStreamPlayer in pool: p.stop()

func _process(delta: float) -> void:
 if beds.size() != 3: return
 var now := Time.get_ticks_msec() / 1000.0
 var duck := -7.0 if now < duck_until else 0.0
 var combat_index := AudioServer.get_bus_index(bus_names[1])
 var old := AudioServer.get_bus_volume_db(combat_index)
 AudioServer.set_bus_volume_db(combat_index, lerpf(old, duck, minf(1.0, delta * (18.0 if duck < old else 3.5))))
 var wind_target := -30.0 + minf(float(industry_count),3.0) * 0.8 + duck * 0.4
 beds[0].volume_db = move_toward(beds[0].volume_db, wind_target, delta * 15.0)
 var power_target := (-34.0 if power_active else -60.0) + duck * 0.4
 beds[1].volume_db = move_toward(beds[1].volume_db, power_target, delta * 14.0)
 var threat_target := (-36.0 + threat * 10.0 if threat > 0.01 else -75.0) + duck * 0.4
 beds[2].volume_db = move_toward(beds[2].volume_db, threat_target, delta * 10.0)

func _exit_tree() -> void:
 # Remove only our buses, after children are stopped.
 for pool: Array in pools:
  for p: AudioStreamPlayer in pool:
   if is_instance_valid(p): p.stop()
 for p in beds:
  if is_instance_valid(p): p.stop()
 for i in range(bus_names.size() - 1, -1, -1):
  var index := AudioServer.get_bus_index(bus_names[i])
  if index > 0: AudioServer.remove_bus(index)
