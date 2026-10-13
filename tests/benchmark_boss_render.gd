extends SceneTree
func _initialize():call_deferred("run")
func run():
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_squad_return.json"))
 var c=root.get_node("Campaign");c.current=int(data.mission);c.launch=true;c.resume=false;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
 if not g.load_checkpoint():push_error("Fixture rejected");quit(1);return
 for frame in 3:await process_frame
 var old=load(OS.get_environment("RECLAMATION_BASELINE_SOURCE").path_join("horde_renderer.gd")).new();g.add_child(old)
 var candidate=g.horde_renderer
 var output={"scope":"Native render-data CPU only; fixed earned 94-enemy snapshot plus separately labelled one-boss insertion, not FPS", "cases":[]}
 for add_boss in [false,true]:
  if add_boss:g.spawn_enemy(Vector3(6,0,8),false,true,true)
  var records=g.enemies
  for renderer in [old,candidate]:
   for i in 40:renderer.update_horde(records,g.elapsed)
  var samples=[]
  for renderer in [old,candidate,candidate,old]:
   var begin=Time.get_ticks_usec()
   for i in 200:renderer.update_horde(records,g.elapsed)
   samples.append({"renderer":"baseline" if renderer==old else "candidate","mean_ms":float(Time.get_ticks_usec()-begin)/200000.0})
  output.cases.append({"enemies":records.size(),"inserted_boss":add_boss,"samples":samples})
 var result=FileAccess.open("user://boss_render_cpu.json",FileAccess.WRITE);result.store_string(JSON.stringify(output,"  "));result.close()
 print("BOSS_CPU ",JSON.stringify(output));old.free();g.free();quit()
