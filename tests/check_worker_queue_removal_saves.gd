extends SceneTree
const Orders=preload("res://worker_orders.gd")
const Validation=preload("res://checkpoint_validation.gd")
var g:Node
var passed:int=0
var failed:int=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.resume=false;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.wave_clock=100000;g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 var w:Dictionary=g.units.filter(func(u):return u.kind=="worker")[0]
 var worker_index:int=g.units.find(w)
 var garden:Dictionary=g.make_building("garden",Vector3(-4,0,19),true);g.building_completed(garden)
 var resource:Dictionary=g.resource_nodes.back()
 g.economy.assign_resource(w,resource)
 g.selected=[w];g.set_build("house")
 check(g.place_building(Vector3(2,0,19),true),"paused removal fixture has a real paid pending foundation")
 var foundation:Dictionary=g.buildings.back()
 w.cargo=3.0;w.cargo_kind="food";w.economy_phase="to_resource"
 g.paused=true
 check(g.dismantle_building(garden),"garden is dismantled while paused before economy can refresh its target")
 var d:Dictionary=g.checkpoint_data()
 var saved:Dictionary=d.units[worker_index]
 check(Validation.validate(d) and saved.resource_target_index==-1 and saved.economy_phase=="" and saved.cargo==3 and saved.pending_orders.size()==1,"snapshot normalizes a removed active resource while preserving cargo and pending work")
 check(w.economy_phase=="to_resource" and w.resource_target==resource,"snapshot normalization does not mutate live economy state")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"paused removed-resource checkpoint writes and loads atomically")
 w=g.units[worker_index];foundation=Orders.pending(w)[0].target
 check(w.task=="gather" and w.cargo==3 and Orders.pending(w).size()==1 and foundation.paid_resources.salvage==40,"removed-resource reload preserves paid foundation and carried load")

 var depot:Dictionary=g.make_building("depot",Vector3(-4,0,19),true)
 var food:Dictionary=g.resource_nodes.filter(func(r):return r.resource=="food")[0]
 g.economy.assign_resource(w,food)
 w.cargo=4.0;w.cargo_kind="food";w.economy_phase="to_dropoff";w.dropoff_target=depot
 check(g.dismantle_building(depot),"current drop-off is dismantled while paused")
 d=g.checkpoint_data();saved=d.units[worker_index]
 check(Validation.validate(d) and saved.dropoff_index==-1 and saved.economy_phase=="waiting_dropoff" and saved.cargo==4 and saved.pending_orders.size()==1,"snapshot normalizes a missing drop-off without dropping cargo or FIFO")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"paused removed-drop-off checkpoint writes and loads atomically")
 w=g.units[worker_index];foundation=Orders.pending(w)[0].target
 var before:float=g.stockpile.food
 g.paused=false
 for step in 1500:
  g.advance_simulation_time(.05)
  if w.task=="build":break
 check(w.task=="build" and w.target==foundation and w.cargo==0 and g.stockpile.food==before+4,"loaded gather finds HQ, deposits once, then starts paid queued foundation")
 d=g.checkpoint_data();d.units[worker_index].gather_requires_work=true
 check(not Validation.validate(d),"gather-work marker is rejected outside active gathering")
 d=g.checkpoint_data();d.units[worker_index].gather_requires_work="true"
 check(not Validation.validate(d),"gather-work marker requires a boolean")
 print("WORKER_QUEUE_REMOVAL_SAVES_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.free();await process_frame;quit(1 if failed else 0)
