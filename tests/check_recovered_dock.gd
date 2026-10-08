extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1180,737);root.content_scale_size=root.size
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.paused=true
 assert(g.desktop_command_dock!=null)
 g.select_headquarters();g.refresh_context_commands(true);g.update_ui()
 var before=g.stockpile.food
 g.context_actions[0].button.pressed.emit()
 assert(g.stockpile.food==before-50 and g.buildings[0].queue.size()==1)
 g.refresh_context_commands(true);g.update_ui()
 var cancel=g.context_actions.filter(func(a):return "予約を取消" in a.button.get_meta("command_title",a.button.text))
 # Match by established context key, not texture children or private positions.
 assert(g.activate_context_key(KEY_E))
 assert(g.stockpile.food==before and g.buildings[0].queue.is_empty())
 g.select_workers();g.refresh_context_commands(true);g.update_ui()
 for frame in 8:await process_frame
 for b in g.command_grid.get_children():assert(b.size.x>=180 and b.size.y>=70)
 assert(g.command_grid.columns==4)
 var worker_height=g.desktop_command_dock.panel.size.y
 g.select_guards();g.refresh_context_commands(true);g.update_ui()
 for frame in 5:await process_frame
 assert(g.command_grid.get_child_count()==2)
 assert(g.desktop_command_dock.panel.size.y<worker_height)
 assert(g.save_checkpoint(false)==OK)
 print("RECOVERED_DOCK_FLOW_PASS queue_refund_exact=true workers_columns=4 combat_actions=2 saved=true")
 g.free();await process_frame;quit()
