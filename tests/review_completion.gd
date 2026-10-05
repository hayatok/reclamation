extends SceneTree
## Native result composition review. Default scenes explicitly force completion.
## --earned-convoy instead replays a paid final leg from an unmodified earned save.
var g:Node
func _initialize():call_deferred("run")
func run():
 if FileAccess.file_exists("user://settlement_v2/checkpoint.json"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 var mission_index=0
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--review-mission="):mission_index=clampi(int(argument.trim_prefix("--review-mission=")),0,2)
 var earned="--earned-convoy" in OS.get_cmdline_user_args()
 if earned:
  mission_index=1;DirAccess.make_dir_recursive_absolute("user://settlement_v2")
  var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
  f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_m2_prelaunch.json"));f.close()
 var c=root.get_node("Campaign");c.current=mission_index;c.launch=true;c.resume=earned;c.muted=not ("--review-audio" in OS.get_cmdline_user_args());c.run_seed=20261005
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 if earned:
  g.selected=g.units.filter(func(u):return u.kind in ["guard","grenade","siegecart"])
  g.choose_convoy_route(1);g.command_at(g.convoy_unit().node.position);g.paused=false
  for tick in 3000:
   g.advance_simulation_time(.05)
   if g.ended:break
  assert(g.ended and g.result_won,"Earned final leg must actually deliver")
  print("EARNED_COMPLETION_REVIEW elapsed=",g.elapsed," convoy_hp=",g.convoy_unit().hp)
 else:
  for s in g.sites:
   s.reclaimed=true;g.StructureVisuals.set_site_reclaimed(s.node,true)
  g.finish(true)
  print("CONTROLLED_COMPOSITION_REVIEW mission=",mission_index,"; forced completion, not earned campaign evidence")
 g.set_process(true)
