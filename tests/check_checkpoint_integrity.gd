extends SceneTree
const Validation=preload("res://checkpoint_validation.gd")
const Atomic=preload("res://atomic_save.gd")
const PATH="user://settlement_v2/checkpoint.json"
var passed=0
var failed=0
var g:Node
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func write_text(path:String,value:String):
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:check(false,"fixture opens "+path);return
 file.store_string(value);file.close()
func discard_files(path:String):
 for suffix in ["",".bak",".tmp",".bak.tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
func reject(data:Dictionary,label:String):
 check(not Validation.validate(data),label)
func paths(value:Variant,prefix:Array=[])->Array:
 var found=[]
 if value is Dictionary:
  for key in value:
   var path=prefix+[key];found.append(path);found.append_array(paths(value[key],path))
 elif value is Array:
  for i in value.size():
   var path=prefix+[i];found.append(path);found.append_array(paths(value[i],path))
 return found
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 await process_frame
 var initial=g.checkpoint_data()
 check(Validation.validate(initial),"actual fresh scene passes exact schema")
 if not Validation.validate(initial):
  write_text("user://invalid_initial.json",JSON.stringify(initial," "));quit(1);return
 var worker=g.units[2]
 g.stockpile={"food":400.0,"salvage":200.0,"parts":50.0}
 check(g.production.queue_unit(g.buildings[0],"worker"),"paid production queues")
 g.production.update(6)
 g.economy.assign_resource(worker,g.resource_nodes[0])
 worker.cargo=5.0;worker.cargo_kind=g.resource_nodes[0].resource
 g.spawn_enemy(Vector3(4,0,4));g.enemies[0].dead=true
 g.spawn_enemy(Vector3(6,0,6))
 var guard=g.units[0]
 guard.task="focus_fire";guard.target=g.enemies[1]
 g.units[1].task="escort";g.units[1].target=guard;g.units[1].escort_slot=2
 g.selected=[worker,guard]
 g.xp=300;g.bank_earned_upgrades();g.open_growth_choices();g.postpone_growth_choice()
 var cards=g.cards.map(func(card):return card.id)
 var growth_rng=str(g.card_rng.state)
 var combat_rng=str(g.rng.state)
 var pending=g.pending_upgrade_levels.duplicate()
 check(pending.size()==3 and cards.size()==3 and not g.active_card,"three earned levels and postponed cards fixture")
 g.launch_shell(Vector3(0,2,0),Vector3(3,0,3),85,4.5,"mortar",true)
 g.shells[0].time=.4
 var data=g.checkpoint_data()
 check(Validation.validate(data),"actual relationship-rich checkpoint validates")
 if not Validation.validate(data):
  write_text("user://invalid_fixture.json",JSON.stringify(data," "));quit(1);return
 check(g.save_checkpoint(false)==OK,"actual checkpoint writes successfully")
 check(data.units[0].target_index==0,"focus-fire index uses living-enemy serialization")
 g.stockpile.food=1;worker.cargo=0;g.buildings[0].queue[0].remaining=999;g.cards.clear();g.pending_upgrade_levels.clear();g.card_rng.randf()
 check(g.load_checkpoint(),"actual scene loads validated checkpoint")
 check(g.stockpile.food==350 and g.units[2].cargo==5 and g.buildings[0].queue[0].remaining==12,"economy, cargo, paid queue progress roundtrip")
 check(g.units[0].target==g.enemies[0] and g.units[1].target==g.units[0],"focus-fire and escort relationships roundtrip")
 check(g.pending_upgrade_levels==pending and g.cards.map(func(card):return card.id)==cards and str(g.card_rng.state)==growth_rng and not g.active_card,"postponed queue, same cards, RNG roundtrip")
 check(str(g.rng.state)==combat_rng,"combat RNG is restored after object construction")
 check(g.shells.size()==1 and is_equal_approx(g.shells[0].time,.4) and g.shells[0].critical,"in-flight shell roundtrip")
 check(g.open_growth_choices() and str(g.card_rng.state)==growth_rng and g.cards.map(func(card):return card.id)==cards,"reopening restored choices does not draw")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint() and g.active_card,"open-card UI roundtrip")
 g.postpone_growth_choice()
 var mutations=[]
 var bad=data.duplicate(true);bad.units[0].goal[1]="wrong";mutations.append([bad,"nested goal type"])
 bad=data.duplicate(true);bad.units[0].hp=NAN;mutations.append([bad,"NaN health"])
 bad=data.duplicate(true);bad.enemies[0].attack_pos[0]=INF;mutations.append([bad,"infinite vector"])
 bad=data.duplicate(true);bad.buildings[0].queue[0].paid_cost.food="50";mutations.append([bad,"queue cost type"])
 bad=data.duplicate(true);bad.buildings[0].queue[0].remaining=-1;mutations.append([bad,"queue remaining range"])
 bad=data.duplicate(true);bad.buildings[0].queue[0].kind="truck";mutations.append([bad,"queue producer relation"])
 bad=data.duplicate(true);bad.units[2].resource_kind="parts" if bad.resource_nodes[0].resource!="parts" else "food";mutations.append([bad,"resource-kind relationship"])
 bad=data.duplicate(true);bad.units[0].dropoff_index=0.5;mutations.append([bad,"fractional depot index"])
 bad=data.duplicate(true);bad.units[0].dropoff_index=999;mutations.append([bad,"dangling depot index"])
 bad=data.duplicate(true);bad.units[0].return_assignment.resource="bad";mutations.append([bad,"return assignment kind"])
 bad=data.duplicate(true);bad.resource_nodes[0].source_building_index=0;mutations.append([bad,"resource owner must be garden"])
 bad=data.duplicate(true);bad.selected=[-1];mutations.append([bad,"negative selection index"])
 bad=data.duplicate(true);bad.units[0].task="escort";bad.units[0].target_type="unit";bad.units[0].target_index=1;mutations.append([bad,"escort cycle"])
 bad=data.duplicate(true);bad.cards[0]="missing_card";mutations.append([bad,"unknown saved card"])
 bad=data.duplicate(true);bad.pending_upgrade_levels=[2,2,4];mutations.append([bad,"growth FIFO consistency"])
 bad=data.duplicate(true);bad.upgrades={"damage":6};mutations.append([bad,"rank cap"])
 bad=data.duplicate(true);bad.rng="9223372036854775808";mutations.append([bad,"overflow RNG string"])
 bad=data.duplicate(true);bad.sites.clear();mutations.append([bad,"required objective sites"])
 bad=data.duplicate(true);bad.convoy_index=999;mutations.append([bad,"convoy route index"])
 for item in mutations:reject(item[0],item[1])
 var field_paths=paths(data)
 var escaped=[]
 for path in field_paths:
  var changed=data.duplicate(true)
  var cursor=changed
  for component in path.slice(0,path.size()-1):cursor=cursor[component]
  var key=path[-1]
  cursor[key]=[] if cursor[key] is String else "wrong_type"
  if Validation.validate(changed):escaped.append(str(path))
 check(escaped.is_empty(),"all %d saved field/container types reject corrupt values: %s"%[field_paths.size(),str(escaped)])
 # The real loader must reject a malformed nested value without changing a
 # single live node, collection, resource, order or pending choice.
 var live_ids=g.units.map(func(unit):return unit.node.get_instance_id())
 var live_state=JSON.stringify(g.checkpoint_data())
 discard_files(PATH);write_text(PATH,JSON.stringify(mutations[0][0]))
 check(not g.load_checkpoint() and live_ids==g.units.map(func(unit):return unit.node.get_instance_id()) and live_state==JSON.stringify(g.checkpoint_data()),"malformed nested load leaves entire live world unchanged")
 write_text(PATH,'{"version":2,')
 check(not g.load_checkpoint() and live_state==JSON.stringify(g.checkpoint_data()),"truncated load leaves live world unchanged")
 # Exercise real filesystem failures and interrupted protocol states.
 discard_files(PATH)
 var prior=data.duplicate(true);prior.elapsed=11
 var next=data.duplicate(true);next.elapsed=22
 check(Atomic.write_json(PATH,prior,Validation.validate)==OK and Atomic.write_json(PATH,next,Validation.validate)==OK,"atomic update retains prior valid save")
 check(Atomic.read_valid(PATH+".bak",Validation.validate).elapsed==11,"backup contains complete prior checkpoint")
 write_text(PATH,'{"truncated":')
 check(Validation.read(PATH).elapsed==11 and Validation.last_read_used_backup,"truncated current recovers validated backup")
 write_text(PATH+".tmp",JSON.stringify(next))
 check(Validation.read(PATH).elapsed==11,"uncommitted complete temp does not outrank valid backup")
 write_text(PATH+".bak","[]")
 check(Validation.read(PATH).elapsed==22,"valid temp recovers when committed copies are invalid")
 check(Atomic.write_json(PATH,prior,Validation.validate)==OK and Atomic.read_valid(PATH+".bak",Validation.validate).elapsed==22,"next save preserves only-valid interrupted temp before reuse")
 discard_files(PATH)
 write_text(PATH+".bak.tmp",JSON.stringify(prior))
 check(Validation.read(PATH).elapsed==11 and Atomic.write_json(PATH,next,Validation.validate)==OK and Atomic.read_valid(PATH+".bak",Validation.validate).elapsed==11,"interrupted backup staging is recoverable and protected on next save")
 var before_bytes=FileAccess.get_file_as_bytes(PATH)
 discard_files(PATH+".tmp")
 DirAccess.make_dir_absolute(PATH+".tmp")
 check(Atomic.write_json(PATH,next,Validation.validate)!=OK and FileAccess.get_file_as_bytes(PATH)==before_bytes,"failed temp open reports failure and preserves current")
 DirAccess.remove_absolute(PATH+".tmp")
 DirAccess.make_dir_absolute(PATH+".bak.tmp")
 check(Atomic.write_json(PATH,next,Validation.validate)!=OK and FileAccess.get_file_as_bytes(PATH)==before_bytes,"failed backup staging preserves current")
 DirAccess.remove_absolute(PATH+".bak.tmp")
 DirAccess.remove_absolute(PATH+".bak")
 DirAccess.make_dir_absolute(PATH+".bak")
 check(Atomic.write_json(PATH,prior,Validation.validate)!=OK and FileAccess.get_file_as_bytes(PATH)==before_bytes,"failed backup promotion does not replace current")
 DirAccess.remove_absolute(PATH+".bak")
 discard_files(PATH)
 DirAccess.make_dir_absolute(PATH)
 write_text(PATH+".bak",JSON.stringify(prior))
 check(Atomic.write_json(PATH,next,Validation.validate)!=OK and Validation.read(PATH).elapsed==11,"failed final rename preserves valid backup and reports failure")
 DirAccess.remove_absolute(PATH)
 discard_files(PATH)
 write_text(PATH,"false");write_text(PATH+".bak","{}");write_text(PATH+".tmp","[]")
 check(Validation.read(PATH).is_empty(),"all invalid copies never become a checkpoint")
 discard_files(PATH)
 check(g.save_checkpoint(false)==OK,"resume checkpoint exists before completion failure")
 var saved_bytes=FileAccess.get_file_as_bytes(PATH)
 check(campaign.save_progress()==OK,"campaign initial progress saves atomically")
 var wrong_progress={"version":1,"unlocked":2,"best":{"0":{"time":"wrong","kills":3}},"muted":false,"low_fx":false,"performance_mode":false}
 check(not campaign.validate_progress(wrong_progress),"malformed nested campaign best record rejected")
 var progress_bytes=FileAccess.get_file_as_bytes("user://settlement_v2/campaign.json")
 DirAccess.make_dir_absolute("user://settlement_v2/campaign.json.tmp")
 g.finish(true)
 check(g.result_progress_error!=OK and FileAccess.get_file_as_bytes(PATH)==saved_bytes and FileAccess.get_file_as_bytes("user://settlement_v2/campaign.json")==progress_bytes,"failed campaign completion preserves resumable checkpoint and previous progress")
 DirAccess.remove_absolute("user://settlement_v2/campaign.json.tmp")
 g.retry_completion_save()
 check(g.result_progress_error==OK and not FileAccess.file_exists(PATH) and not FileAccess.file_exists(PATH+".bak"),"successful retry records victory before clearing checkpoint copies")
 print("CHECKPOINT_INTEGRITY_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
