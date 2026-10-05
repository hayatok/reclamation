extends SceneTree
const Orders=preload("res://worker_orders.gd")
const Validation=preload("res://checkpoint_validation.gd")
const Nav=preload("res://friendly_navigation.gd")
var g:Node
var passed:int=0
var failed:int=0
var bounded:bool=true
var safe:bool=true
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func tick(count:int=1):
 for step in count:
  var previous:Array=g.units.map(func(u):return u.node.position)
  g.advance_simulation_time(.05)
  bounded=bounded and g.friendly_navigation.queries_this_frame<=Nav.MAX_QUERIES_PER_FRAME
  for i in g.units.size():
   if g.units[i].kind=="worker":safe=safe and Nav.segment_open(g.nav,previous[i],g.units[i].node.position)
func place(kind:String,point:Vector3,append:bool=false)->Dictionary:
 g.set_build(kind)
 if not g.place_building(point,append):return {}
 return g.buildings.back()
func finish_fixture(worker:Dictionary):
 if worker.task=="build":worker.target.built=1.0
 elif worker.task=="repair":worker.target.hp=worker.target.maxhp
 g.finish_construction_order(worker)
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.resume=false;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.wave_clock=100000;g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 var workers:Array=g.units.filter(func(u):return u.kind=="worker")
 var w:Dictionary=workers[0]
 var salvage:Dictionary=g.resource_nodes.filter(func(r):return r.resource=="salvage")[0]
 g.selected=[w];g.update_selection()
 var a:Dictionary=place("house",Vector3(-4,0,19))
 var b:Dictionary=place("house",Vector3(2,0,19),true)
 check(not a.is_empty() and not b.is_empty(),"normal and Shift placements create legal foundations")
 if a.is_empty() or b.is_empty():quit(1);return
 check(w.target==a and Orders.pending(w).size()==1 and Orders.pending(w)[0].target==b,"Shift foundation appends without replacing active construction")
 check(g.build_mode=="house" and g.ghost.visible,"Shift placement retains the same preview")
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;g._unhandled_input(escape)
 check(g.build_mode.is_empty() and Orders.pending(w).size()==1,"Escape cancels only the unplaced preview")
 g.command_at(salvage.node.position,Vector2.INF,true)
 check(Orders.pending(w).size()==2 and Orders.pending(w)[1].task=="gather","explicit gather appends after both foundations")
 check(g.stockpile.salvage==920 and a.paid_resources.salvage==40 and b.paid_resources.salvage==40,"each legal foundation is charged exactly once")
 tick(20)
 var live_target:Dictionary=w.target
 var pending_target:Dictionary=Orders.pending(w)[0].target
 var paid_before:float=g.stockpile.salvage
 check(g.save_checkpoint(false)==OK,"atomic checkpoint accepts active and pending paid orders")
 check(g.load_checkpoint(),"actual load restores worker queues")
 workers=g.units.filter(func(u):return u.kind=="worker");w=workers[0]
 a=g.buildings.filter(func(entry):return entry.node.position==live_target.node.position)[0]
 b=g.buildings.filter(func(entry):return entry.node.position==pending_target.node.position)[0]
 salvage=g.resource_nodes.filter(func(r):return r.resource=="salvage")[0]
 check(w.target==a and Orders.pending(w).size()==2 and Orders.pending(w)[0].target==b and Orders.pending(w)[1].target==salvage,"reload resolves exact FIFO target identities")
 check(g.stockpile.salvage==paid_before,"reload does not replay construction payment")
 var sequence_ok:bool=true
 for step in 2500:
  tick()
  if b.built>0 and a.built<1:sequence_ok=false
  if w.task=="gather" and (a.built<1 or b.built<1):sequence_ok=false
  if a.built==1 and b.built==1 and g.stockpile.salvage>paid_before:break
 check(sequence_ok and a.built==1 and b.built==1 and w.task=="gather" and g.stockpile.salvage>paid_before,"ordinary simulation completes A then B then gathers and deposits")
 check(Orders.pending(w).is_empty(),"completed sequence consumes FIFO exactly once")

 # Explicit next work from renewable gathering yields only after a real deposit.
 g.selected=[w];g.stop_selected()
 var garden:Dictionary=g.make_building("garden",Vector3(-10,0,21),true);g.building_completed(garden)
 var food:Dictionary=g.resource_nodes.back()
 g.economy.assign_resource(w,food)
 var c:Dictionary=place("house",Vector3(8,0,19),true)
 check(not c.is_empty() and w.task=="gather" and Orders.pending(w).size()==1,"renewable gathering keeps active work while build is pending")
 var before_food:float=g.stockpile.food
 var boundary_ok:bool=true
 for step in 1800:
  tick()
  if w.task=="build":
   boundary_ok=g.stockpile.food>before_food and w.cargo==0
   break
 check(boundary_ok and w.task=="build" and w.target==c,"renewable gather hands off only after crediting one delivery")
 check(w.has("return_assignment"),"queued construction preserves original gather fallback")
 var d:Dictionary=g.make_building("house",Vector3(14,0,20))
 Orders.submit(g,w,{"task":"build","target":d,"goal":d.node.position},true)
 finish_fixture(w)
 check(w.target==d and w.has("return_assignment"),"consecutive construction precedes automatic gather return")
 finish_fixture(w)
 check(w.task=="gather" and w.resource_target==food,"exhausted construction queue resumes original gathering")

 # Replacing and rejecting commands must be transactional with paid foundations.
 g.selected=[w];g.command_at(Vector3(10,0,25))
 Orders.submit(g,w,{"task":"build","target":c,"goal":c.node.position},true)
 var queued_before:int=Orders.pending(w).size()
 var stock_before:Dictionary=g.stockpile.duplicate()
 var count_before:int=g.buildings.size()
 g.set_build("house")
 check(not g.place_building(a.node.position,true) and Orders.pending(w).size()==queued_before and g.stockpile==stock_before and g.buildings.size()==count_before,"invalid overlap changes neither payment, foundations, nor pending orders")
 g.stockpile.salvage=0
 check(not g.place_building(Vector3(20,0,22),true) and Orders.pending(w).size()==queued_before and g.buildings.size()==count_before,"unaffordable placement preserves all paid orders")
 g.stockpile=stock_before
 g.command_at(salvage.node.position)
 check(Orders.pending(w).is_empty() and w.task=="gather","normal gather replaces pending work")
 Orders.submit(g,w,{"task":"move","goal":Vector3(10,0,25)},true)
 w.cargo=3.0;w.cargo_kind="salvage"
 g.stop_selected()
 check(Orders.pending(w).is_empty() and w.task=="idle" and w.cargo==3 and not w.has("return_assignment"),"Stop clears active, pending, and fallback while preserving cargo")

 # Group preflight, shared payment, mixed selection, and full capacity.
 w.cargo=0.0;w.cargo_kind=""
 g.selected=[workers[0],workers[1]];g.stop_selected()
 var shared_before:float=g.stockpile.salvage
 var shared:Dictionary=place("house",Vector3(20,0,22),true)
 check(not shared.is_empty() and workers[0].target==shared and workers[1].target==shared and g.stockpile.salvage==shared_before-40,"two idle builders share a single charged foundation")
 var soldier:Dictionary=g.units.filter(func(u):return u.kind=="guard")[0]
 var soldier_task:String=soldier.task;var soldier_goal:Vector3=soldier.goal
 g.selected=[w,soldier];g.command_at(Vector3(10,0,25),Vector2.INF,true)
 check(soldier.task==soldier_task and soldier.goal==soldier_goal and Orders.pending(w).size()==1,"mixed Shift selection queues workers without retasking soldiers")
 while Orders.pending(w).size()<Orders.MAX_PENDING:Orders.submit(g,w,{"task":"move","goal":Vector3(10,0,25)},true)
 g.selected=[w,workers[1]]
 g.set_build("house");stock_before=g.stockpile.duplicate();count_before=g.buildings.size()
 check(not g.place_building(Vector3(20,0,16),true) and g.stockpile==stock_before and g.buildings.size()==count_before and Orders.pending(workers[1]).is_empty(),"one full worker queue rejects grouped placement before charge or partial assignment")
 g.stop_selected()

 # Empty exhausted resource waits hand off; cargo waiting for delivery does not.
 g.economy.assign_resource(w,food)
 w.economy_phase="waiting_resource";w.resource_target=null;w.target=null;w.cargo=0.0
 Orders.submit(g,w,{"task":"build","target":shared,"goal":shared.node.position},true)
 check(w.task=="build" and w.target==shared,"empty waiting_resource starts pending work immediately")
 g.stop_selected();g.economy.assign_resource(w,food)
 w.cargo=4.0;w.cargo_kind="food";w.economy_phase="waiting_dropoff";w.dropoff_target=null
 Orders.submit(g,w,{"task":"build","target":shared,"goal":shared.node.position},true)
 Orders.tick(g,w)
 check(w.task=="gather" and w.cargo==4 and Orders.pending(w).size()==1,"waiting for cargo delivery preserves active gather and queue")
 g.selected=[w];g.stop_selected();w.cargo=0.0;w.cargo_kind=""

 # Removal and completed target handling; save indices must follow array erasure.
 var removed:Dictionary=g.make_building("house",Vector3(-20,0,20))
 var survivor:Dictionary=g.make_building("house",Vector3(-20,0,14))
 Orders.submit(g,w,{"task":"build","target":removed,"goal":removed.node.position})
 Orders.submit(g,w,{"task":"build","target":removed,"goal":removed.node.position},true)
 Orders.submit(g,w,{"task":"build","target":survivor,"goal":survivor.node.position},true)
 Orders.submit(g,w,{"task":"gather","target":salvage,"goal":salvage.node.position},true)
 var old_index:int=g.buildings.find(survivor)
 check(g.dismantle_building(removed) and w.target==survivor and Orders.pending(w).size()==1,"dismantling active and duplicate queued target safely advances to survivor")
 check(g.buildings.find(survivor)==old_index-1,"fixture removes an earlier building array entry")
 var extra:Dictionary=g.make_building("house",Vector3(-20,0,8))
 Orders.submit(g,w,{"task":"build","target":extra,"goal":extra.node.position},true)
 var snapshot:Dictionary=g.checkpoint_data()
 var saved:Dictionary=snapshot.units[g.units.find(w)]
 check(Validation.validate(snapshot) and saved.target_index==g.buildings.find(survivor) and saved.pending_orders[1].target_index==g.buildings.find(extra),"fresh snapshot resolves active and pending indices after removal")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"removed-index checkpoint passes actual atomic writer and reload")
 w=g.units.filter(func(u):return u.kind=="worker")[0];survivor=w.target;salvage=Orders.pending(w)[0].target;extra=Orders.pending(w)[1].target
 check(w.target==survivor and Orders.pending(w)[1].target==extra,"reload retains remaining paid order after index shifts")
 var worker_index:int=g.units.find(w)
 var bad:Dictionary=g.checkpoint_data()
 bad.units[worker_index].pending_orders[0].target_index=99999
 check(not Validation.validate(bad),"validator rejects nonexistent queued target")
 bad=g.checkpoint_data();bad.units[worker_index].pending_orders[0].task="focus_fire"
 check(not Validation.validate(bad),"validator rejects combat queue entries")
 bad=g.checkpoint_data();bad.units[worker_index].pending_orders[0].goal=[0,0,INF]
 check(not Validation.validate(bad),"validator rejects nonfinite queued coordinates")
 bad=g.checkpoint_data();bad.units[worker_index].pending_orders=[]
 for i in Orders.MAX_PENDING+1:bad.units[worker_index].pending_orders.append({"task":"move","target_type":"","target_index":-1,"goal":[0,0,0]})
 check(not Validation.validate(bad),"validator rejects over-cap FIFO")

 # A satisfied build never becomes an unrequested repair; a lost gather is skipped.
 g.selected=[w];g.stop_selected()
 Orders.submit(g,w,{"task":"move","goal":Vector3(12,0,25)})
 extra.built=1.0;extra.hp-=5
 Orders.submit(g,w,{"task":"build","target":extra,"goal":extra.node.position},true)
 var resource:Dictionary=g.make_resource("food",Vector3(20,0,-20),5)
 Orders.submit(g,w,{"task":"gather","target":resource,"goal":resource.node.position},true)
 Orders.submit(g,w,{"task":"move","goal":Vector3(16,0,25)},true)
 g.resource_nodes.erase(resource);resource.node.queue_free()
 Orders.finish(g,w)
 check(w.task=="move" and w.goal==Vector3(16,0,25) and extra.hp<extra.maxhp and Orders.pending(w).is_empty(),"completed build and removed gather skip without repair, recharge, or stale-node access")
 check(bounded and safe,"ordinary sequence retains navigation query budget and safe movement")
 print("WORKER_ORDER_QUEUE_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;quit(1 if failed else 0)
