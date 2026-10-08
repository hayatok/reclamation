extends SceneTree
## Controlled risky move using normal units, costs and enemy damage. The authored
## destination is a test input, not a claim of a novice or blind AI playthrough.
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok:bool,title:String):
 if ok:passed+=1
 else:failed+=1;push_error(title)
func run():
 var campaign=root.get_node("Campaign");campaign.current=1;campaign.launch=true;campaign.resume=false;campaign.muted=true;campaign.choose_run_seed(4451)
 var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 var scout=game.units[0];var reserve=game.units[1]
 game.selected=[scout];game.inspected={}
 check(not game.frontier_position_known(Vector3(-42,0,-18)),"camp destination starts unexplored")
 game.command_at(Vector3(-42,0,-18))
 for tick in 2400:
  game.simulate(.05)
  if scout not in game.units or game.ended:break
 check(scout not in game.units and not game.ended,"isolated scout lost to ordinary camp damage")
 # Visibility updates at 5Hz; allow one bounded refresh after death cleanup.
 for tick in 5:game.simulate(.05)
 check(game.frontier_visibility.is_explored(Vector3(-42,0,-18)),"scouted terrain persists")
 check(not game.frontier_visibility.is_visible(Vector3(-42,0,-18)),"lost scout no longer grants current sight")
 check(game.combat_targets().is_empty(),"remote camp stops being targetable")
 game.selected=[reserve];game.command_at(game.map_config.home+Vector3(-5,0,-4))
 for tick in 100:game.simulate(.05)
 check(reserve in game.units and not game.ended,"remaining force can regroup")
 var state=game.checkpoint_data()
 check(game.valid_checkpoint(state),"post-loss checkpoint valid")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);file.store_string(JSON.stringify(state));file.close()
 check(game.load_checkpoint(),"post-loss actual reload")
 check(game.units.size()==state.units.size() and game.frontier_visibility.is_explored(Vector3(-42,0,-18)),"reload preserves survivors and exploration")
 # Deliberately do not prepare defenses after the loss. End only through actual AI attacks.
 for tick in 8000:
  if game.ended:break
  if game.active_card:game.choose_upgrade(game.cards[0])
  game.simulate(.05)
 check(game.ended and not game.result_won,"undefended headquarters eventually loses normally")
 print("FRONTIER_SCOUT_LOSS_RESULT passed=",passed," failed=",failed," elapsed=",game.elapsed," hp=",game.buildings[0].hp)
 game.free();await process_frame;quit(0 if failed==0 else 1)
