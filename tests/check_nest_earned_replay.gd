extends SceneTree
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_assault.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.resume=true;c.launch=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=false
 var states=[]
 for i in 200:
  if g.ended:break
  g.simulate(.05)
  if i%20==0:states.append(g.checkpoint_data())
 states.append(g.checkpoint_data())
 var result={"states":states,"won":g.result_won,"ended":g.ended,"elapsed":g.elapsed,"nest_dead":g.frontier.nest.dead,"kills":g.kills}
 f=FileAccess.open(OS.get_environment("NEST_REPLAY_OUT") if not OS.get_environment("NEST_REPLAY_OUT").is_empty() else "user://nest_earned_replay.json",FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close()
 var passed=g.ended and g.result_won and g.frontier.nest.dead
 print("NEST_EARNED_REPLAY ",passed," t=",g.elapsed," kills=",g.kills)
 g.free();await process_frame;quit(0 if passed else 1)
