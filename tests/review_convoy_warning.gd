extends SceneTree
## Replay an unmodified earned save with ordinary paid launch/escort commands.
## Pause only when the actual warning appears so its short-lived UI can be inspected.
var g:Node
var captured=false
func _initialize():call_deferred("run")
func run():
 if FileAccess.file_exists("user://settlement_v2/checkpoint.json"):
  push_error("Fresh isolated XDG_DATA_HOME required for earned fixture review");quit(2);return
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_m2_prelaunch.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g
 g.selected=g.units.filter(func(u):return u.kind in ["guard","grenade","siegecart"])
 g.update_selection();g.choose_convoy_route(1)
 g.command_at(g.convoy_unit().node.position)
 g.camera_focus=Vector3(-18,0,14);g.camera.size=42
 g.paused=false
func _process(_dt):
 if is_instance_valid(g) and not captured and not g.convoy_pending.is_empty():
  captured=true;g.paused=true;g.update_ui()
  print("EARNED_NATIVE_WARNING_HELD ",g.objective.text)
 return false
