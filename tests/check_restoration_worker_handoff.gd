extends SceneTree
## Run with the game as --path and this absolute --script path, using isolated XDG_DATA_HOME.
const Orders=preload("res://worker_orders.gd")
var g:Node
var workers:Array=[]
var passed:int=0
var failures:Array=[]

func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if ok:passed+=1
 else:failures.append(label)
func tick(count:int=1):
 for step in count:g.simulate(.05)
func resource(kind:String)->Dictionary:
 return g.resource_nodes.filter(func(r):return r.resource==kind)[0]
func reset_workers():
 g.selected.assign(workers);g.stop_selected()
 for worker in workers:worker.cargo=0.0;worker.cargo_kind=""
func reset_site(site:Dictionary):
 site.reclaimed=false;site.progress=0.0;site.paid=false
func begin_site(site:Dictionary,cargo:float=0.0)->Dictionary:
 reset_workers();reset_site(site)
 var w:Dictionary=workers[0]
 g.economy.assign_resource(w,resource("salvage"))
 w.cargo=cargo;w.cargo_kind="food" if cargo>0 else ""
 g.selected=[w]
 check(g.command_at(site.node.position) and w.task=="site" and w.target==site,site.kind+" accepts actual restoration command")
 return w
func arrive(w:Dictionary,site:Dictionary)->bool:
 for step in 1600:
  if w.task!="site" or w.target!=site:return false
  if site.paid and g.friendly_navigation.is_work_arrived(w,g.nav):return true
  tick()
 return false
func complete(w:Dictionary,site:Dictionary):
 if not arrive(w,site):
  check(false,site.kind+" reaches its actual work perimeter")
  return
 site.progress=.999999
 g.work_site(w,.05)
func has_fallback(w:Dictionary,target:Dictionary)->bool:
 return w.get("return_assignment",{}).get("target")==target
func gathering(w:Dictionary,target:Dictionary)->bool:
 return w.task=="gather" and w.get("resource_target")==target

func run():
 var campaign=root.get_node("Campaign")
 campaign.current=2;campaign.launch=true;campaign.resume=false;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.wave_clock=100000;g.auto_save_clock=100000;g.generator_on=false
 g.stockpile={"food":10000.0,"salvage":10000.0,"parts":10000.0};g.settlement_age=3
 workers=g.units.filter(func(u):return u.kind=="worker")
 var salvage:Dictionary=resource("salvage")
 var food:Dictionary=resource("food")
 var gen:Dictionary=g.get_site("generator")
 var pump:Dictionary=g.get_site("pump")
 var w:Dictionary

 # Actual command dispatch, legal path/work reservation, charge and completion.
 for kind in ["generator","pump","substation"]:
  var site:Dictionary=g.get_site(kind)
  var stock:Dictionary=g.stockpile.duplicate()
  w=begin_site(site,5.0)
  check(has_fallback(w,salvage) and w.economy_phase=="suspended",kind+" suspends previous gathering")
  complete(w,site)
  check(site.reclaimed and gathering(w,salvage) and not w.has("return_assignment"),kind+" completion resumes exact original resource")
  check(w.cargo==5.0 and w.cargo_kind=="food" and w.economy_phase=="to_dropoff",kind+" retains mismatched carried load for delivery")
  var expected:Dictionary=stock.duplicate()
  for cost_kind in g.site_rule(kind).cost:expected[cost_kind]-=g.site_rule(kind).cost[cost_kind]
  check(g.stockpile==expected,kind+" charges restoration once without instant cargo credit")

 # A queued explicit order wins. Subsequent construction retains the old fallback.
 w=begin_site(gen)
 check(g.command_at(food.node.position,Vector2.INF,true),"explicit gathering queues behind restoration")
 complete(w,gen)
 check(gathering(w,food) and not w.has("return_assignment") and Orders.pending(w).is_empty(),"queued gather replaces automatic return")
 w=begin_site(gen,5.0)
 var move_goal:Vector3=Vector3(0,0,25)
 check(g.command_at(move_goal,Vector2.INF,true),"explicit movement queues behind restoration")
 var queued_goal:Vector3=Orders.pending(w)[0].goal
 complete(w,gen)
 check(w.task=="move" and w.goal==queued_goal and not w.has("return_assignment") and w.cargo==5,"queued move wins and preserves cargo")
 var house:Dictionary=g.make_building("house",Vector3(-4,0,22))
 w=begin_site(gen)
 check(g.command_at(house.node.position,Vector2.INF,true),"explicit construction queues behind restoration")
 complete(w,gen)
 check(w.task=="build" and w.target==house and has_fallback(w,salvage),"queued construction wins while retaining original resource")
 house.built=1.0;g.finish_construction_order(w)
 check(gathering(w,salvage),"restoration then construction returns after final explicit job")

 # Another worker's completion is observed by the ordinary simulation cleanup.
 w=begin_site(gen)
 var second:Dictionary=workers[1]
 g.economy.assign_resource(second,food);g.selected=[w,second]
 check(g.command_at(gen.node.position),"two workers accept one restoration")
 check(arrive(w,gen),"first worker reaches shared restoration")
 gen.progress=.999999;tick()
 check(gen.reclaimed and gathering(w,salvage) and gathering(second,food),"same simulation step returns both workers to their own resources")
 w=begin_site(gen)
 gen.reclaimed=true;gen.progress=1.0;g.work_site(w,.05)
 check(gathering(w,salvage),"already-reclaimed direct work exit resumes gathering")

 # Accepted replacement orders preserve or deliberately clear the fallback.
 w=begin_site(gen,5.0);reset_site(pump)
 check(g.command_at(pump.node.position) and w.target==pump and has_fallback(w,salvage),"replacement restoration keeps original fallback")
 complete(w,pump)
 check(gathering(w,salvage) and w.cargo==5,"replacement restoration returns with unchanged cargo")
 house.built=0.0
 w=begin_site(gen)
 check(g.command_at(house.node.position) and w.task=="build" and has_fallback(w,salvage),"replacement building keeps original fallback")
 house.built=1.0;g.finish_construction_order(w)
 check(gathering(w,salvage),"replacement building completes back into gathering")
 w=begin_site(gen,5.0)
 check(g.command_at(food.node.position) and gathering(w,food) and not w.has("return_assignment"),"replacement gather owns the new assignment")
 w=begin_site(gen,5.0)
 check(g.command_at(move_goal) and w.task=="move" and not w.has("return_assignment") and w.cargo==5,"replacement movement cancels fallback while retaining cargo")
 w=begin_site(gen,5.0)
 g.stop_selected();tick()
 check(w.task=="idle" and not w.has("return_assignment") and w.cargo==5,"Stop cancels fallback without discarding cargo")

 # Rejection is transactional; runtime loss/rejection releases valid old work.
 reset_workers();reset_site(gen);g.settlement_age=1
 w=workers[0];g.economy.assign_resource(w,salvage);w.cargo=3;w.cargo_kind="salvage"
 Orders.submit(g,w,{"task":"gather","target":food,"goal":food.node.position},true)
 g.selected=[w]
 var before:Dictionary=g.checkpoint_data()
 check(not g.command_at(gen.node.position) and g.checkpoint_data()==before,"age rejection preserves saved active work, cargo, queue and RNG")
 g.settlement_age=3
 w=begin_site(gen)
 check(arrive(w,gen),"runtime age rejection fixture arrives legally")
 var paid:Dictionary=g.stockpile.duplicate();var progress:float=gen.progress
 g.settlement_age=1;g.work_site(w,.05);g.settlement_age=3
 check(gathering(w,salvage) and gen.progress==progress and g.stockpile==paid,"runtime age rejection resumes without work or another charge")
 w=begin_site(gen)
 w.target=null;g.work_site(w,.05)
 check(gathering(w,salvage),"null restoration target resumes original gathering")
 w=begin_site(gen)
 var site_index:int=g.sites.find(gen)
 g.sites.erase(gen);g.work_site(w,.05);g.sites.insert(site_index,gen)
 check(gathering(w,salvage) and not gen.paid and gen.progress==0,"removed live site is rejected before direct restoration work")
 w=begin_site(gen)
 g.sites.erase(gen);tick();g.sites.insert(site_index,gen)
 check(gathering(w,salvage) and not gen.paid,"ordinary simulation releases removed restoration target")

 # Save at real partially completed restoration; resolve references on reload.
 w=begin_site(gen,5.0)
 check(arrive(w,gen),"checkpoint fixture reaches paid restoration")
 gen.progress=.25;house.built=0.0
 check(g.command_at(house.node.position,Vector2.INF,true),"checkpoint fixture queues future construction")
 paid=g.stockpile.duplicate()
 var saved:bool=g.save_checkpoint(false)==OK
 check(saved,"active restoration, cargo, fallback and queue save atomically")
 var loaded:bool=saved and g.load_checkpoint()
 check(loaded,"active restoration checkpoint reloads")
 if loaded:
  workers=g.units.filter(func(u):return u.kind=="worker");w=workers[0]
  gen=g.get_site("generator");salvage=resource("salvage")
  check(w.task=="site" and w.target==gen and gen.paid and gen.progress==.25 and has_fallback(w,salvage),"reload restores exact site and gather fallback references")
  check(w.cargo==5 and w.cargo_kind=="food" and Orders.pending(w).size()==1 and g.stockpile==paid,"reload retains old cargo and explicit queue without payment replay")
  complete(w,gen)
  check(w.task=="build" and has_fallback(w,salvage) and g.stockpile==paid,"reloaded restoration honors queued building without repayment")
  if w.task=="build":
   w.target.built=1.0;g.finish_construction_order(w)
  check(gathering(w,salvage) and w.cargo==5 and w.cargo_kind=="food" and w.economy_phase=="to_dropoff","reloaded work chain resumes original assignment and carried-load delivery")
 print("RESTORATION_HANDOFF_RESULT ",JSON.stringify({"passed":passed,"failed":failures}))
 g.free();await process_frame;quit(0 if failures.is_empty() else 1)
