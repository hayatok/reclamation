extends SceneTree
# Portable integration test. Run from an isolated copy with isolated XDG_DATA_HOME.
var passed:int=0
var failed:int=0
var g:Node
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func same_cost(a:Dictionary,b:Dictionary)->bool:
 if a.size()!=b.size():return false
 for kind in a:
  if not b.has(kind) or not is_equal_approx(float(a[kind]),float(b[kind])):return false
 return true
func press(key:int):
 var event=InputEventKey.new();event.keycode=key;event.pressed=true;g._unhandled_input(event)
func choose_units(value:Array):
 g.selected=value;g.inspected={};g.inspected_resource={};g.inspected_site={};g.update_selection()
func choose_building(value:Dictionary):
 g.selected.clear();g.inspected=value;g.inspected_resource={};g.inspected_site={};g.update_selection()
func stop_all():
 choose_units(g.units.duplicate());g.stop_selected();choose_units([])
func run():
 root.get_node("Campaign").launch=true
 root.get_node("Campaign").current=0
 root.get_node("Campaign").muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 await process_frame
 g.wave_clock=10000
 var hq:Dictionary=g.buildings[0]
 var workers:Array=g.units.filter(func(u):return u.kind=="worker")
 var guards:Array=g.units.filter(func(u):return u.kind=="guard")
 var food:Dictionary=g.resource_nodes[0]
 var start_count:int=g.units.size()
 g.select_headquarters();var food_before:float=g.stockpile.food
 press(KEY_Q)
 check(hq.queue.size()==1 and hq.queue[0].kind=="worker","HQ Q queues worker locally")
 check(g.units.size()==start_count,"HQ Q does not instant spawn")
 check(g.stockpile.food==food_before-50 and hq.queue[0].paid_cost=={"food":50},"HQ Q deducts exact food vector")
 g.command_at(food.node.position)
 check(hq.rally_target==food,"producer right click sets resource rally")
 g.production.update(18)
 var newborn:Dictionary=g.units.back()
 check(g.units.size()==start_count+1 and newborn.kind=="worker","production completes after elapsed duration")
 check(newborn.task=="gather" and newborn.resource_target==food,"HQ newborn follows resource rally")
 g.economy.cancel_assignment(newborn);newborn.task="idle"
 var barracks:Dictionary=g.make_building("barracks",Vector3(12,0,20),true)
 choose_building(barracks);var before:Dictionary=g.stockpile.duplicate()
 press(KEY_Q)
 check(barracks.queue.size()==1 and hq.queue.is_empty(),"barracks Q owns its guard queue")
 check(g.stockpile.food==before.food-60 and g.stockpile.salvage==before.salvage-25,"guard cost has food and salvage")
 g.command_at(Vector3(20,0,24));g.production.update(22)
 var guard:Dictionary=g.units.back()
 check(guard.kind=="guard" and guard.node.position.distance_to(barracks.node.position)<7,"guard spawns at selected barracks")
 check(guard.goal==Vector3(20,0,24),"guard receives barracks ground rally")
 choose_units([workers[0]]);before=g.stockpile.duplicate();start_count=g.units.size()
 press(KEY_Q)
 check(g.build_mode=="house" and g.units.size()==start_count,"worker Q starts house placement only")
 check(g.stockpile==before,"house is not paid before placement")
 check(g.place_building(Vector3(-4,0,19)),"selected worker can place house")
 var house:Dictionary=g.buildings.back()
 check(house.kind=="house" and house.built==0 and workers[0].task=="build","house starts unfinished with worker assignment")
 check(g.stockpile.salvage==before.salvage-40 and house.paid_resources=={"salvage":40},"house placement pays exact vector")
 check(workers.slice(1).all(func(w):return w.task=="idle"),"house construction does not recruit unselected workers")
 choose_units([guards[0]]);before=g.stockpile.duplicate();start_count=g.units.size()
 press(KEY_Q);g.recruit("worker");g.set_build("house")
 check(g.units.size()==start_count and g.stockpile==before and hq.queue.is_empty() and g.build_mode.is_empty(),"combat context cannot train or build")
 check(g.attack_move,"combat Q is attack move")
 g.attack_move=false;choose_units([]);before=g.stockpile.duplicate();press(KEY_Q)
 check(g.stockpile==before and hq.queue.is_empty() and g.build_mode.is_empty(),"empty context has no Q creation")
 choose_units([workers[1],guards[0]]);before=g.stockpile.duplicate();press(KEY_Q)
 check(g.context_actions.size()==3 and g.command_heading.text=="混成部隊","mixed context exposes only stop and filters")
 check(g.stockpile==before and g.build_mode.is_empty(),"mixed Q is common stop, no build or train")
 press(KEY_W)
 check(g.selected.size()==1 and g.selected[0]==workers[1],"mixed worker filter selects only workers")
 # Single-click, shift toggle and drag use actual screen projection.
 workers[1].node.position=Vector3(-4,0,10);workers[2].node.position=Vector3(-3.9,0,10)
 var s:Vector2=g.camera.unproject_position(workers[1].node.position+Vector3(0,.8,0))
 g.select_rect(s,s)
 check(g.selected.size()==1 and g.selected[0]==workers[1],"single click chooses exactly one among nearby units")
 var s2:Vector2=g.camera.unproject_position(guards[0].node.position+Vector3(0,.8,0))
 g.select_rect(s2,s2,true)
 check(g.selected.size()==2 and guards[0] in g.selected,"Shift click adds one unit")
 g.select_rect(s2,s2,true)
 check(g.selected.size()==1 and not guards[0] in g.selected,"Shift click toggles exact unit off")
 g.select_rect(Vector2.ZERO,Vector2(1440,900))
 check(g.selected.size()==g.units.size(),"drag selects multiple units")
 stop_all()
 choose_units([workers[1]]);g.command_at(food.node.position)
 check(workers[1].task=="gather" and workers[1].resource_target==food,"worker resource right click gathers")
 g.command_at(house.node.position)
 check(workers[1].task=="build" and workers[1].target==house and workers[1].return_assignment.target==food,"unfinished building overrides gathering with resumable build job")
 house.built=1;house.hp=house.maxhp-30
 g.command_at(house.node.position)
 check(workers[1].task=="repair" and workers[1].target==house,"damaged building right click repairs")
 var garden:Dictionary=g.make_building("garden",Vector3(-14,0,20),true);g.building_completed(garden)
 g.command_at(garden.node.position)
 check(workers[1].task=="gather" and workers[1].resource_target.source_building==garden,"healthy garden right click gathers food")
 garden.hp=garden.maxhp-20;g.command_at(garden.node.position)
 check(workers[1].task=="repair" and workers[1].target==garden,"damaged garden right click prioritizes repair")
 garden.hp=garden.maxhp
 stop_all()
 # Gather collection changes carried loads only. Deliveries credit once.
 for index in 3:
  var w:Dictionary=workers[index];var resource:Dictionary=g.resource_nodes[index];var kind:String=resource.resource
  before=g.stockpile.duplicate();var stock:float=resource.stock
  g.economy.assign_resource(w,resource);w.node.position=w.goal
  g.economy.update_worker(w,1)
  check(w.cargo>0 and resource.stock<stock and g.stockpile==before,kind+" harvest is cargo only")
  w.cargo=g.worker_carry_capacity(w,kind);var amount:float=w.cargo
  g.economy.update_worker(w,0)
  check(w.economy_phase=="to_dropoff" and g.stockpile==before,kind+" travels before bank credit")
  w.node.position=w.goal;g.economy.update_worker(w,0)
  check(g.stockpile[kind]==before[kind]+amount and w.cargo==0,kind+" credits exactly at delivery")
  g.economy.update_worker(w,0)
  check(g.stockpile[kind]==before[kind]+amount,kind+" cannot double credit delivery")
 stop_all()
 # All population space is consumed, then a house completes.
 house.built=0;g.stockpile.food=1000
 choose_building(hq);press(KEY_Q);g.production.update(18)
 check(hq.queue.size()==1 and hq.queue[0].waiting=="population","finished worker waits at population cap")
 var pop:int=g.production.population_used();house.built=1;g.production.update(.01)
 check(hq.queue.is_empty() and g.production.population_used()==pop+1,"completed house immediately unblocks population wait")
 stop_all()
 # Depot loss reroutes carried goods to HQ without crediting on destruction.
 var depot:Dictionary=g.make_building("depot",Vector3(15,0,12),true)
 var w:Dictionary=workers[3];g.economy.assign_resource(w,g.resource_nodes[1]);w.node.position=Vector3(14,0,11)
 w.cargo=12;w.cargo_kind="salvage";g.economy.assign_resource(w,g.resource_nodes[1]);g.economy.update_worker(w,0)
 check(w.dropoff_target==depot,"nearest completed depot receives delivery")
 before=g.stockpile.duplicate();depot.hp=0;g.economy.update_worker(w,0)
 check(w.dropoff_target==hq and w.cargo==12 and g.stockpile==before,"depot loss reroutes cargo to HQ without credit")
 stop_all()
 # Exhaust all near food: local retarget cannot pull a worker across the map.
 for resource in g.resource_nodes:
  if resource.resource=="food":resource.stock=0
 garden.hp=0;g.remove_garden_resource(garden)
 var far:Dictionary=g.make_resource("food",Vector3(23,0,-23),100)
 w=workers[0];w.node.position=Vector3(-8,0,11);w.cargo=0
 g.economy.assign_resource(w,food);g.economy.update_worker(w,0)
 check(w.economy_phase=="waiting_resource" and w.goal==w.node.position,"exhausted local node waits when only resource is over 20m away")
 g.economy.assign_resource(w,far)
 check(w.economy_phase=="to_resource" and w.resource_target==far,"explicit far resource assignment bypasses local retarget limit")
 g.economy.assign_resource(w,food)
 var near_garden:Dictionary=g.make_building("garden",Vector3(-13,0,16),true);g.building_completed(near_garden)
 g.economy.update_worker(w,0)
 check(w.resource_target!=null and w.resource_target.source_building==near_garden,"waiting food worker automatically finds nearby garden")
 # Save queue progress, payment, resource rally, delivery, suspended construction and escort.
 stop_all();food.stock=50;g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 g.set_rally(hq,food.node.position);g.production.queue_unit(hq,"worker");g.production.update(7)
 w=workers[0];w.cargo=10;w.cargo_kind="food";g.economy.assign_resource(w,food);g.economy.update_worker(w,0)
 var builder:Dictionary=workers[1];g.economy.assign_resource(builder,g.resource_nodes[2]);builder.cargo=3;builder.cargo_kind="parts"
 choose_units([builder]);house.built=.5;house.hp=house.maxhp;g.command_at(house.node.position)
 var escort:Dictionary=guards[0];choose_units([escort]);g.command_at(workers[2].node.position)
 check(escort.task=="escort" and escort.target==workers[2],"right click friendly assigns escort")
 var saved_remaining:float=hq.queue[0].remaining;var saved_paid:Dictionary=hq.queue[0].paid_cost.duplicate();before=g.stockpile.duplicate()
 var delivery_goal:Vector3=w.goal;var house_paid:Dictionary=house.paid_resources.duplicate()
 var wi:int=g.units.find(w);var bi:int=g.units.find(builder);var ei:int=g.units.find(escort);var ti:int=g.units.find(workers[2]);var hi:int=g.buildings.find(house)
 g.save_checkpoint(false)
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://settlement_v2/checkpoint.json"))
 check(saved.version==2 and g.valid_checkpoint(saved),"version 2 checkpoint passes validator")
 var old:Dictionary=saved.duplicate(true);old.version=1
 check(not g.valid_checkpoint(old),"version 1 checkpoint is safely rejected")
 check(g.load_checkpoint(),"version 2 checkpoint loads")
 await process_frame
 hq=g.buildings[0];w=g.units[wi];builder=g.units[bi];escort=g.units[ei];house=g.buildings[hi]
 check(g.stockpile==before and hq.queue[0].remaining==saved_remaining and same_cost(hq.queue[0].paid_cost,saved_paid),"save restores stockpile and queue progress/paid vector")
 check(same_cost(house.paid_resources,house_paid) and house.built==.5,"save restores construction progress/paid vector")
 check(hq.rally_target==g.resource_nodes[0] and hq.rally==food.node.position if is_instance_valid(food.node) else hq.rally_target==g.resource_nodes[0],"save restores producer resource rally")
 check(w.cargo==10 and w.cargo_kind=="food" and w.task=="gather" and w.economy_phase=="to_dropoff" and w.dropoff_target==hq and w.goal==delivery_goal,"save restores cargo/job/dropoff and delivery goal")
 check(builder.cargo==3 and builder.task=="build" and builder.target==house and builder.return_assignment.target==g.resource_nodes[2] and builder.return_assignment.resource=="parts","save restores suspended gathering/return assignment")
 check(escort.task=="escort" and escort.target==g.units[ti],"save restores escort target")
 w.node.position=w.goal;g.economy.update_worker(w,0);g.economy.update_worker(w,0)
 check(g.stockpile.food==before.food+10 and w.cargo==0,"loaded cargo delivers once without double credit")
 before=g.stockpile.duplicate()
 check(g.production.cancel_last(hq),"restored queue can be cancelled")
 check(g.stockpile.food==before.food+50,"restored paid vector refunds exact resources")
 g.production.cancel_last(hq)
 check(g.stockpile.food==before.food+50,"repeated cancel does not double refund")
 before=g.stockpile.duplicate();var before_units:int=g.units.size()
 var old_file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);old_file.store_string(JSON.stringify(old));old_file.close()
 check(not g.load_checkpoint() and g.stockpile==before and g.units.size()==before_units,"old version load rejects without mutating live world")
 print("V09_CONTEXT_INTEGRATION_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;quit(1 if failed else 0)
