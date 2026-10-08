extends SceneTree
func _initialize():call_deferred("run")
func describe(values:Array)->Dictionary:
 var sorted=values.duplicate();sorted.sort();var total=0.0
 for value in sorted:total+=value
 return {"mean":total/maxi(1,sorted.size()),"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max":sorted.back(),"samples":sorted.size()}
func run():
 var checkpoint="";var output=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--checkpoint="):checkpoint=arg.trim_prefix("--checkpoint=")
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);file.store_string(FileAccess.get_file_as_string(checkpoint));file.close()
 var campaign=root.get_node("Campaign");campaign.current=1;campaign.resume=true;campaign.launch=true;campaign.muted=true
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.paused=false
 assert(game.elapsed>700)
 var samples=[];var friend_queries=[];var enemy_queries=[];var visibility=[]
 var probe=game.FrontierVisibility.new();probe.configure(game.map_config.playable_bounds,1)
 var start=game.elapsed
 for tick in 500:
  if game.ended:break
  var before=Time.get_ticks_usec();game.simulate(.05);samples.append((Time.get_ticks_usec()-before)/1000.0)
  friend_queries.append(game.friendly_navigation.queries_this_frame);enemy_queries.append(game.enemy_navigation.queries_this_step)
  # A separate observer field reads actors; never advances the live sight clock.
  before=Time.get_ticks_usec();probe.update_sources(game.units,game.buildings,0,true);probe.get_mask_texture();visibility.append((Time.get_ticks_usec()-before)/1000.0)
 var data={"from":start,"to":game.elapsed,"units":game.units.size(),"enemies":game.enemies.size(),"simulation_ms":describe(samples),"friendly_queries":describe(friend_queries),"enemy_queries":describe(enemy_queries),"forced_visibility_ms":describe(visibility),"limits":"Headless CPU timing of one earned route; not render, browser or physical phone performance. Forced visibility sample is separate from simulation timing."}
 file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close();print("FRONTIER_CPU_PROFILE ",JSON.stringify(data))
 game.free();await process_frame;quit()
