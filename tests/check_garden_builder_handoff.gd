extends SceneTree
const Orders=preload("res://worker_orders.gd")
var g:Node
var failures:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures.append(message)
func run():
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 var workers=g.units.filter(func(u):return u.kind=="worker")
 var w:Dictionary=workers[0]
 var salvage:Dictionary=g.resource_nodes.filter(func(r):return r.resource=="salvage")[0]
 var garden:Dictionary=g.make_building("garden",Vector3(-10,0,21),true);g.building_completed(garden)
 var food:Dictionary=g.resource_nodes.back()
 g.economy.assign_resource(w,salvage)
 Orders.submit(g,w,{"task":"build","target":garden})
 g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==food,"completed garden gives builder a food job")
 check(not w.has("return_assignment"),"old assignment cannot return after the new food job")
 Orders.submit(g,w,{"task":"build","target":garden})
 Orders.submit(g,w,{"task":"gather","target":salvage},true)
 g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==salvage,"explicit queued gathering takes priority")
 Orders.submit(g,w,{"task":"build","target":garden})
 Orders.submit(g,w,{"task":"move","goal":Vector3(10,0,25)},true)
 g.finish_construction_order(w)
 check(w.task=="move" and w.goal==Vector3(10,0,25),"explicit queued movement takes priority")
 g.economy.assign_resource(w,salvage)
 var house:Dictionary=g.make_building("house",Vector3(8,0,20),true)
 Orders.submit(g,w,{"task":"build","target":house});g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==salvage,"ordinary construction returns to the prior job")
 Orders.submit(g,w,{"task":"repair","target":garden});g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==salvage,"garden repair keeps prior gathering")
 Orders.submit(g,w,{"task":"build","target":garden});garden.hp=0;g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==salvage,"destroyed garden cannot assign food")
 garden.hp=garden.maxhp
 w.cargo=5.0;w.cargo_kind="salvage"
 var stock:Dictionary=g.stockpile.duplicate()
 Orders.submit(g,w,{"task":"build","target":garden});g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==food and w.economy_phase=="to_dropoff" and w.cargo==5 and w.cargo_kind=="salvage" and g.stockpile==stock,"old carried load is retained for delivery without conversion or instant credit")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"garden assignment survives actual checkpoint reload")
 w=g.units.filter(func(u):return u.kind=="worker")[0]
 check(w.task=="gather" and w.resource_target.resource=="food" and w.resource_target.get("source_building",{}).get("kind")=="garden" and w.cargo==5 and w.cargo_kind=="salvage","reload keeps food destination and old cargo type")
 print("GARDEN_HANDOFF_RESULT ",JSON.stringify({"failed":failures}))
 quit(0 if failures.is_empty() else 1)
