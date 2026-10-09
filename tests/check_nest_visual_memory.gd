extends SceneTree
const Art=preload("res://frontier_nest_visual.gd")
var failures=0
func check(ok:bool,title:String):
 print("PASS " if ok else "FAIL ",title)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/native_rebuild_after_scout_loss.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 var n=g.frontier.nest.node
 check(g.frontier.nest.known and not g.frontier_visibility.is_visible(n.position),"actual scout-loss save has known but unseen nest")
 check(n.visible and n.get_node("Intact").visible,"known building remains visible as fogged terrain")
 var before=g.checkpoint_data();g.refresh_frontier_visibility(0,true)
 check(g.checkpoint_data()==before,"presentation refresh preserves complete simulation state")
 var core:ShaderMaterial=n.get_meta("frontier_core_material")
 Art.set_state(n,false,true)
 check(core.get_shader_parameter("alarm")==0.0,"unseen alarm does not leak through memory")
 Art.set_state(n,true,false)
 check(n.get_node("Intact").visible and not n.get_node("Rubble").visible,"unobserved structural change does not alter last seen shape")
 Art.set_observed(n,true,true)
 check(n.get_node("Rubble").visible,"returning vision updates observed shape")
 Art.set_state(n,false,true)
 check(core.get_shader_parameter("alarm")==1.0,"current sight restores live alarm cue")
 g.frontier.nest.known=false
 check(not g.frontier.discover_if_visible(func(_p):return false) and not n.visible,"unknown nest remains completely hidden")
 check(g.frontier.discover_if_visible(func(_p):return true) and n.visible,"real sight discovers nest once")
 check(not g.frontier.discover_if_visible(func(_p):return true),"discovery notice is not repeated")
 print("NEST_MEMORY_RESULT failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
