extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,what:String):
 if not ok:failures+=1;push_error(what)
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(4451)
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 var leader=g.make_unit("siegecart",g.map_config.home+Vector3(7,0,4))
 var followers=[g.units[0],g.units[1]]
 g.selected=followers+[leader];g.inspected={};g.update_selection()
 var actions=g.context_actions
 check(actions[0].kind=="attack" and actions[0].key==KEY_Q and actions[1].kind=="select" and actions[1].key==KEY_W,"existing action/hotkey ordering")
 leader.task="move";leader.goal=leader.node.position+Vector3(5,0,0)
 var old_goal=leader.goal
 g.begin_escort()
 check(g.escort_targeting,"button enters explicit target choice")
 check(not g.choose_escort_target(Vector3(95,0,79)),"empty terrain rejected")
 check(followers[0].task=="idle","rejected target preserves old order")
 check(g.choose_escort_target(leader.node.position),"selected leader can be target")
 check(leader.task=="move" and leader.goal==old_goal,"leader order preserved")
 for u in followers:check(u.task=="escort" and u.target==leader,"followers use existing escort")
 check(not g.escort_targeting and g.selected.size()==3,"selection preserved, intent cleared")
 check(g.valid_checkpoint(g.checkpoint_data()),"assigned escort checkpoint valid")
 g.begin_escort();g.cancel_targeting_mode();check(not g.escort_targeting,"cancel clears pending intent")
 check(followers[0].task=="escort","cancel does not stop issued escort")
 g.begin_escort();g.stop_selected();check(not g.escort_targeting and followers[0].task=="idle","stop cancels mode and orders")
 g.begin_escort();g.select_workers();check(not g.escort_targeting,"selection change cancels mode")
 print("EXPLICIT_ESCORT_RESULT failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
