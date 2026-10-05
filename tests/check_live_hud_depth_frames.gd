extends SceneTree
const Probe=preload("res://tests/live_hud_depth_probe.gd")
const Mask=preload("res://hud_depth_mask.gd")
class LastProcess:
 extends Node
 signal observed
 func _process(_delta):observed.emit()
func _initialize():call_deferred("run")
func run():
 var marker=LastProcess.new();marker.process_priority=1000000;root.add_child(marker)
 var reference:Dictionary={}
 for phase in 2:
  var campaign=root.get_node("Campaign");campaign.current=0;campaign.launch=true;campaign.resume=true;campaign.muted=true;campaign.performance_mode=false
  var game=load("res://main.tscn").instantiate();game.set_script(Probe);game.set_process(false)
  root.add_child(game);current_scene=game;game.set_process(false)
  assert(is_equal_approx(game.elapsed,677.3) and game.units.size()==16 and game.enemies.size()==13)
  var mask=game.hud_depth_mask;mask.enabled=phase==1;mask.sync_now()
  for warm in 3:await marker.observed
  assert(game.benchmark_frames==0 and is_equal_approx(game.elapsed,677.3),"Preparation advanced the game")
  game.benchmark_frames=0;game.paused=false;game.set_process(true)
  for frame in 150:await marker.observed
  game.set_process(false)
  assert(game.benchmark_frames==150,"Wrong logical callback count")
  assert(is_equal_approx(game.elapsed,679.8),"Wrong logical elapsed time")
  var state=game.checkpoint_data()
  if reference.is_empty():reference=state.duplicate(true)
  assert(state==reference,"Mask changed live gameplay state")
  print("LIVE_HUD_FRAME_GATE phase=",phase," frames=",game.benchmark_frames," elapsed=",game.elapsed," units=",game.units.size()," enemies=",game.enemies.size()," state_equal=true")
  game.free()
 print("LIVE_HUD_FRAME_GATE_PASS")
 quit()
