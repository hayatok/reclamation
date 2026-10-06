extends SceneTree
## Controlled observation of the unmodified earned battle. No free resources,
## injected enemies, or order automation; pause once at a natural worker hit.
var game
var trace:Array=[]
var last_groups:Array=[]
var last_selected:Array=[]
var worker_pause_done:bool=false
func _initialize():call_deferred("run")
func run():
 if FileAccess.file_exists("user://settlement_v2/checkpoint.json"):push_error("Use fresh isolated data");quit(2);return
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_critical_factory.json"));file.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 if game.title_open or game.elapsed<500:push_error("Strict load failed");quit(3);return
 game.paused=true
 for i in 6:root.mode=Window.MODE_WINDOWED;root.size=Vector2i(844,390);await process_frame
 print("TOUCH_GROUP_FLOW_READY t=",game.elapsed)
 watch.call_deferred()
func save_trace(kind:String):
 trace.append({"event":kind,"elapsed":game.elapsed,"groups":game.control_groups.snapshot(game.units,game.buildings),"selected":game.selected.map(func(u):return game.units.find(u)),"paused":game.paused,"camera":game.vec_data(game.camera_focus)})
 var file=FileAccess.open("user://touch_group_flow_trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace,"  "));file.close()
func watch():
 while is_instance_valid(game) and not game.ended:
  await process_frame
  var groups:Array=game.control_groups.snapshot(game.units,game.buildings)
  var selected:Array=game.selected.map(func(u):return game.units.find(u))
  if groups!=last_groups:last_groups=groups.duplicate(true);save_trace("group_changed")
  if selected!=last_selected:last_selected=selected.duplicate();save_trace("selection_changed")
  var alert:Dictionary=game.building_attack_alerts.current
  if not worker_pause_done and not alert.is_empty() and alert.target.get("kind","")=="worker":
   worker_pause_done=true;game.paused=true;save_trace("observation_pause_worker_hit")
   game.capture_frame()
   print("OBSERVATION_PAUSE worker_hit t=",game.elapsed," hp=",alert.target.hp)
