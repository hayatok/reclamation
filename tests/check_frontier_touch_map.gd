extends SceneTree
## Synthetic touch events through the actual adapter. Not a physical-phone test.
var g:Node
var checks=0
var failed=0
func _initialize():call_deferred("run")
func check(ok:bool,title:String):
 if not ok:failed+=1;push_error(title)
 else:checks+=1
func touch(point:Vector2,pressed:bool,index:int=0):
 var e=InputEventScreenTouch.new();e.position=point;e.pressed=pressed;e.index=index;g._input(e)
func tap(point:Vector2):touch(point,true);touch(point,false)
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(4451)
 root.size=Vector2i(844,390)
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 await process_frame;await process_frame
 check(g.mobile_enabled,"touch override active")
 g.mobile_hud.sync();g.mobile_input.sync()
 var fighter=g.units[0];g.selected=[fighter];g.inspected={};g.update_selection()
 var chosen=Vector3(70,0,-55)
 var map_point=g.minimap.global_position+g.MissionMap.world_to_map(g.map_config,chosen,g.minimap.size)
 var old_goal=fighter.goal
 tap(map_point)
 check(g.camera_focus.distance_to(chosen)<.01,"map tap moves camera across broad district")
 check(fighter.goal==old_goal and fighter in g.selected,"camera map tap preserves selection and order")
 var origin=g.camera_focus
 touch(map_point,true)
 var drag=InputEventScreenDrag.new();drag.position=map_point+Vector2(20,0);drag.index=0;g._input(drag)
 touch(map_point+Vector2(20,0),false)
 check(g.camera_focus==origin and fighter.goal==old_goal,"drag release never issues map tap")
 var order=Vector3(-18,0,32)
 map_point=g.minimap.global_position+g.MissionMap.world_to_map(g.map_config,order,g.minimap.size)
 g.touch_set_mode(2);tap(map_point)
 check(fighter.task=="move" and fighter.goal.distance_to(order)<3,"explicit touch map order uses broad command bounds")
 check(g.mobile_input.controller.mode==0,"order mode returns to context")
 # Rotate while a map finger is held: release must not execute a stale tap.
 touch(map_point,true)
 root.size=Vector2i(390,844);root.content_scale_size=Vector2i(390,844)
 await process_frame;await process_frame
 g._mobile_reset("resize");g.mobile_hud.sync();g.mobile_input.sync()
 var before=fighter.goal
 touch(map_point,false)
 check(fighter.goal==before,"rotation cancels held map contact")
 check(g.mobile_hud.size==Vector2(390,844),"portrait HUD reflows")
 check(g.valid_checkpoint(g.checkpoint_data()),"wide touch view is checkpoint-valid")
 print("FRONTIER_TOUCH_MAP_RESULT passed=",checks," failed=",failed)
 g.free();await process_frame;quit(0 if failed==0 else 1)
