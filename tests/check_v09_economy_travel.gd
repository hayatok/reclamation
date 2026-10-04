extends SceneTree
var passed:int=0
var failed:int=0
var g:Node
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func simulate_for(seconds:float):
 for tick in int(seconds*10):g.simulate(.1)
func run():
 root.get_node("Campaign").launch=true;root.get_node("Campaign").current=0;root.get_node("Campaign").muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.wave_clock=10000
 var workers:Array=g.units.filter(func(u):return u.kind=="worker")
 var initial:Dictionary=g.stockpile.duplicate()
 for i in 3:
  g.selected=[workers[i]];g.inspected={};g.command_at(g.resource_nodes[i].node.position)
 simulate_for(50)
 check(g.stockpile.food>initial.food,"real movement delivers food")
 check(g.stockpile.salvage>initial.salvage,"real movement delivers salvage")
 check(g.stockpile.parts>initial.parts,"real movement delivers parts")
 print("TRAVEL_POSITION food=",workers[0].node.position," salvage=",workers[1].node.position," parts=",workers[2].node.position," stockpile=",g.stockpile)
 g.selected=workers.duplicate();g.stop_selected()
 for resource in g.resource_nodes:
  if resource.resource=="food":resource.stock=0
 var near:Dictionary=g.resource_nodes[0];near.stock=3
 var far:Dictionary=g.resource_nodes[7];far.stock=50
 var w:Dictionary=workers[0];w.cargo=0;w.cargo_kind=""
 g.economy.assign_resource(w,near)
 var before:float=g.stockpile.food
 simulate_for(30)
 check(g.stockpile.food>=before+2.99 and w.cargo==0,"depleted partial cargo naturally returns to HQ")
 check(w.economy_phase=="waiting_resource" and w.node.position.distance_to(far.node.position)>20,"worker waits locally rather than crossing map after depletion")
 var stopped:Vector3=w.node.position;simulate_for(10)
 check(w.node.position.distance_to(stopped)<.5,"waiting worker remains near dropoff")
 g.economy.assign_resource(w,far)
 simulate_for(55)
 check(g.stockpile.food>before+3 and far.stock<50,"explicit far assignment actually travels, gathers, and delivers")
 # Return from far job, exhaust food, then offer a nearby garden at the worker's waiting location.
 far.stock=0;simulate_for(25)
 var garden:Dictionary=g.make_building("garden",w.node.position+Vector3(7,0,0),true);g.building_completed(garden)
 before=g.stockpile.food
 simulate_for(65)
 check(w.resource_target!=null and w.resource_target.source_building==garden,"waiting worker automatically assigns nearby completed garden")
 check(g.stockpile.food>before,"nearby garden actually delivers renewable food")
 print("V09_ECONOMY_TRAVEL_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;quit(1 if failed else 0)
