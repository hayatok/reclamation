extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.run_seed=42
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 var expected=["西","東","南"]
 for route in 2:
  g.convoy_route_choice=route
  for stage in 3:
   g.convoy_pending={"stage":stage,"clock":3.5};g.update_ui()
   if not ("追走群 %s / 3.5秒"%expected[stage]) in g.objective.text:
    push_error("Convoy stage %d route %d warning is not visible"%[stage,route]);quit(1);return
 g.convoy_pending={};g.update_ui()
 if "追走群" in g.objective.text:push_error("Expired warning remained");quit(1);return
 print("CONVOY_WARNING_ALL_SIX_ROUTE_STAGES_AND_EXPIRY_PASS")
 g.free();await process_frame;quit(0)
