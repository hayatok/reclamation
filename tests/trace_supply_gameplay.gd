extends SceneTree
func _initialize():call_deferred("run")
func run():
 var output="user://supply_gameplay_trace.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_critical_factory.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=false
 assert(g.enemies.size()==69 and g.elapsed>500)
 var trace=[g.checkpoint_data()]
 for step in 400:
  g.simulate(.05)
  if step%20==19:trace.append(g.checkpoint_data())
 f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(trace));f.close()
 print("SUPPLY_GAMEPLAY_TRACE samples=",trace.size()," kills=",g.kills," ammo=",g.ammo)
 g.queue_free();await process_frame;quit()
