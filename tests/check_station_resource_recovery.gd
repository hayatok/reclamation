extends SceneTree
# Controlled resource-depletion recovery on intact authored M3 terrain.
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.wave_clock=100000;g.auto_save_clock=100000;g.settlement_age=3;g.generator_on=true
 for site in g.sites:site.reclaimed=true;site.paid=true;site.progress=1
 var station=g.get_site("pump");station.hp=0;station.disabled=true;g.hold_time=25
 var w=g.units.filter(func(u):return u.kind=="worker")[0]
 w.node.position=station.node.position+Vector3(4,0,0)
 g.selected=[w];g.resources=0;g.command_at(station.node.position)
 for i in 40:g.simulate(.05)
 assert(w.task=="repair" and station.hp==0 and g.hold_time==25)
 var deposits=g.resource_nodes.filter(func(n):return n.resource=="salvage" and n.stock>0)
 assert(not deposits.is_empty())
 deposits.sort_custom(func(a,b):return a.node.position.distance_squared_to(w.node.position)<b.node.position.distance_squared_to(w.node.position))
 assert(g.command_at(deposits[0].node.position) and w.task=="gather")
 var travel_time=0.0
 for i in 2400:
  g.simulate(.05);travel_time+=.05
  if g.resources>=15:break
 assert(g.resources>=15)
 var returned_resources=g.resources
 assert(g.command_at(station.node.position) and w.task=="repair")
 var repair_time=0.0
 for i in 2400:
  g.simulate(.05);repair_time+=.05
  if not station.disabled:break
 assert(not station.disabled and station.hp>=150 and g.hold_time>=25)
 var result={"scope":"Controlled zero-salvage recovery; ordinary gather/delivery/repair commands, intact M3 navigation, no enemies and no resource injection","gather_delivery_seconds":travel_time,"salvage_delivered":returned_resources,"return_and_repair_seconds":repair_time,"station_hp":station.hp,"hold":g.hold_time,"stock_remaining":deposits[0].stock}
 print("STATION_RESOURCE_RECOVERY ",JSON.stringify(result));g.free();quit()
