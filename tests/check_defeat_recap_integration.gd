extends SceneTree
## Run in the integrated game with a fresh isolated XDG_DATA_HOME.
const Validation=preload("res://checkpoint_validation.gd")
const Recap=preload("res://defeat_recap.gd")
const CHECKPOINT:String="user://settlement_v2/checkpoint.json"
var checks:int=0
var failures:int=0
var g:Node
func _initialize():call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error("FAIL "+label)
func fresh(mission:int=0)->void:
 if is_instance_valid(g):root.remove_child(g);g.free()
 var campaign=root.get_node("Campaign")
 campaign.current=mission;campaign.launch=true;campaign.resume=false;campaign.muted=true;campaign.run_seed=921
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.wave_clock=9999
func clear_enemies()->void:
 for enemy in g.enemies:enemy.node.queue_free()
 g.enemies.clear()
func write_checkpoint(data:Dictionary)->void:
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 for suffix in ["",".bak",".tmp",".bak.tmp"]:
  if FileAccess.file_exists(CHECKPOINT+suffix):DirAccess.remove_absolute(CHECKPOINT+suffix)
 var file=FileAccess.open(CHECKPOINT,FileAccess.WRITE)
 file.store_string(JSON.stringify(data));file.close()
func named_button(text:String)->Button:
 for button in g.modal.find_children("*","Button",true,false):
  if button.text==text:return button
 return null
func run()->void:
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 fresh()
 await process_frame
 check(g.defeat_recap.snapshot().events.is_empty(),"fresh mission has no inherited facts")
 check(Validation.validate(g.checkpoint_data()),"new recorder envelope passes full current checkpoint validator")
 var dismantled:Dictionary=g.make_building("factory",Vector3(11,0,7),true)
 check(g.dismantle_building(dismantled),"actual dismantle flow removes a living factory")
 check(g.defeat_recap.snapshot().events.is_empty(),"actual dismantle does not fabricate hostile destruction")
 var recovered:Dictionary=g.make_building("factory",Vector3(11,0,7),true)
 recovered.hp=0
 g.xp=g.xp_needed();g.bank_earned_upgrades()
 g.cards=[g.UpgradeCatalog.by_id("field_repair")];g.active_card=true
 g.choose_upgrade(0);g.simulate(.05)
 check(recovered.hp>0 and recovered in g.buildings and g.defeat_recap.snapshot().events.is_empty(),"existing field-repair effect can recover HP0 before removal without a false loss")
 g.dismantle_building(recovered)
 var factory:Dictionary=g.make_building("factory",Vector3(11,0,7),true)
 factory.hp=9.0
 for unit in g.units:unit.cd=100.0
 g.elapsed=30.0
 g.spawn_enemy(Vector3(11,0,7));g.enemies.back().cd=0.0
 check(g.save_checkpoint(false)==OK,"pre-hit state saves as a resumable checkpoint")
 var pre_hit_bytes:PackedByteArray=FileAccess.get_file_as_bytes(CHECKPOINT)
 g.simulate(.05)
 var recorded:Dictionary=g.defeat_recap.snapshot()
 check(factory.hp<=0 and recorded.events.is_empty(),"real lethal damage waits for confirmed removal rather than recording a recoverable actor")
 check(not Validation.validate(g.checkpoint_data()) and g.save_checkpoint(false)!=OK and FileAccess.get_file_as_bytes(CHECKPOINT)==pre_hit_bytes,"same-tick save before dead-actor cleanup is rejected and keeps previous durable checkpoint")
 check(g.load_checkpoint() and g.defeat_recap.snapshot().events.is_empty(),"resume after rejected dead-actor save restores pre-hit history")
 factory=g.buildings.filter(func(building):return building.kind=="factory")[0]
 g.simulate(.05)
 check(g.defeat_recap.snapshot()==recorded,"replayed lethal hit after resume does not invent a premature fact")
 clear_enemies()
 g.simulate(.05)
 recorded=g.defeat_recap.snapshot()
 check(factory not in g.buildings and recorded.events.size()==1 and recorded.events[0].kind=="factory","actual cleanup commits exactly one factory loss after resume")
 check(is_equal_approx(float(recorded.events[0].time),g.elapsed),"loss timestamp is the actual confirmed-removal tick")
 g.simulate(.05)
 check(g.defeat_recap.snapshot()==recorded,"later cleanup cannot record the same loss twice")
 var workers:Array=g.units.filter(func(unit):return unit.kind=="worker")
 g.elapsed=40.0;workers[0].hp=0;g.simulate(.05)
 g.elapsed=43.0;workers[1].hp=0;g.simulate(.05)
 check(g.defeat_recap.snapshot().events.size()==2 and g.defeat_recap.snapshot().events.back().count==2,"real unit cleanup groups two worker losses")
 var before_save:Dictionary=g.defeat_recap.snapshot()
 check(g.save_checkpoint(false)==OK,"loss history saves through real atomic checkpoint writer")
 var saved:Dictionary=g.checkpoint_data()
 check(Validation.validate(saved) and saved.defeat_recap==before_save,"checkpoint contains exact primitive recap")
 g.defeat_recap.record_loss({"kind":"garden","hp":0.0,"built":1.0},g.elapsed)
 check(g.load_checkpoint() and g.defeat_recap.snapshot()==before_save,"load replaces divergent live recap with saved history")
 var live_ids:Array=g.units.map(func(unit):return unit.node.get_instance_id())
 var bad:Dictionary=saved.duplicate(true);bad.defeat_recap.events[0].time=g.elapsed+1
 write_checkpoint(bad)
 check(not g.load_checkpoint() and g.units.map(func(unit):return unit.node.get_instance_id())==live_ids and g.defeat_recap.snapshot()==before_save,"invalid recap prevents load before any live-node or recap mutation")
 var absent:Dictionary=saved.duplicate(true);absent.erase("defeat_recap")
 write_checkpoint(absent)
 check(g.load_checkpoint() and g.defeat_recap.snapshot().events.is_empty(),"checkpoint without history starts empty instead of inheriting another run")
 write_checkpoint(saved)
 check(g.load_checkpoint() and g.defeat_recap.snapshot()==before_save,"saved facts restore after absent-history fixture")
 g.elapsed=50.0
 var pending:Dictionary=g.make_building("vehicle_workshop",Vector3(15,0,8),true);pending.hp=0
 var remaining_workers:Array=g.units.filter(func(unit):return unit.kind=="worker")
 remaining_workers[0].hp=0;remaining_workers[1].hp=0
 g.buildings[0].hp=0
 g.finish(false)
 var terminal:Dictionary=g.defeat_recap.snapshot()
 check(terminal.events.any(func(event):return event.kind=="hq") and terminal.events.any(func(event):return event.kind=="vehicle_workshop"),"terminal defeat captures later unprocessed facility losses")
 check(terminal.events.back().time==50 and terminal.events.filter(func(event):return event.kind=="worker").back().count==2,"terminal defeat captures pending workers with current event time")
 var recap_label:Label=g.modal.find_child("DefeatRecap",true,false)
 check(recap_label!=null and recap_label.text=="直前の記録\n"+"\n".join(g.defeat_recap.recent_lines(g.elapsed)),"existing defeat modal displays exact recorder facts")
 check(g.defeat_recap.recent_lines(g.elapsed).size()==3,"defeat result is capped at three facts")
 g.finish(false)
 check(g.defeat_recap.snapshot()==terminal,"repeated finish does not double-count")
 var retry:Button=named_button("この作戦をもう一度")
 check(retry!=null and not retry.disabled and retry.pressed.get_connections().size()>0,"existing retry control remains enabled and connected")
 var old_id:int=g.get_instance_id()
 if retry!=null:
  retry.pressed.emit()
  for frame in 30:
   await process_frame
   if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id:break
  g=current_scene;g.set_process(false)
 check(g.get_instance_id()!=old_id and not g.ended and g.defeat_recap.snapshot().events.is_empty(),"actual Retry starts a clean recorder with fresh actor dictionaries")
 await process_frame
 fresh(1)
 await process_frame
 g.elapsed=70.0
 var convoy:Dictionary=g.make_unit("convoy",Vector3(-20,0,10))
 convoy.hp=45;g.convoy_started=true
 g.spawn_enemy(Vector3(-20,0,10),false,true,true)
 var boss:Dictionary=g.enemies.back();boss.attack_pos=convoy.node.position
 g.boss_impact(boss)
 check(convoy.hp<=0 and g.defeat_recap.snapshot().events.is_empty(),"real boss impact leaves recording to terminal loss confirmation")
 g.simulate(.05)
 check(g.ended and not g.result_won and g.defeat_recap.snapshot().events.size()==1 and g.defeat_recap.snapshot().events[0].kind=="convoy","convoy terminal cleanup records one actual loss")
 check(g.failure_reason=="輸送隊を失った。","defeat wording states verified loss without invented cause")
 fresh()
 await process_frame
 g.elapsed=90;g.finish(false)
 check(g.modal.find_child("DefeatRecap",true,false)==null,"forced loss without recorded casualties invents no extra events")
 print("DEFEAT_RECAP_INTEGRATION_SUMMARY checks=%d failures=%d"%[checks,failures])
 g.queue_free();await process_frame;await process_frame
 quit(0 if failures==0 else 1)
