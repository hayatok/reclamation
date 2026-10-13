extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 for i in 10:g._process(0);await process_frame
 var out="user://objective_panel_review/"
 DirAccess.make_dir_recursive_absolute(out);root.get_texture().get_image().save_png(out+"before.png")
 print("OBJECTIVE_RECT ",g.objective.get_parent().get_parent().get_global_rect())
 var toggle=g.root_ui.find_child("MissionDetailsToggle",true,false)
 var before=JSON.stringify(g.checkpoint_data());var panel=toggle.get_parent().get_parent()
 create_timer(90).timeout.connect(func():quit(2))
 while toggle.get_parent().get_node("MissionDetails").visible:await process_frame
 for i in 8:g._process(0);await process_frame
 root.get_texture().get_image().save_png(out+"collapsed_ready.png")
 assert(not toggle.get_parent().get_node("MissionDetails").visible)
 assert(panel.size.y<180 and g.guide.is_visible_in_tree() and g.status.is_visible_in_tree())
 assert(JSON.stringify(g.checkpoint_data())==before)
 print("COLLAPSED_RECT ",panel.get_global_rect())
 for cycle in 3:
  toggle.emit_signal("pressed");await process_frame;toggle.emit_signal("pressed");await process_frame
 assert(not toggle.get_parent().get_node("MissionDetails").visible)
 g.hold_time=10;g._process(0);await process_frame
 assert(g.objective.is_visible_in_tree() and not toggle.get_parent().get_node("MissionDetails").visible)
 print("OBJECTIVE_FOLD_PASS click, repeated toggle, objective update, checkpoint unchanged")
 g.free();quit()
