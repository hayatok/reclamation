extends SceneTree

const Catalog = preload("res://upgrade_catalog.gd")
var game
var results:Array = []
var failures:Array = []
var units_in_fixture:Array = []
func _initialize():call_deferred("run")
func check(label:String, actual, expected, tolerance:float=0.0001):
 var passed:bool = absf(float(actual)-float(expected))<=tolerance if (actual is float or actual is int) and (expected is float or expected is int) else actual==expected
 var row={"name":label,"actual":actual,"expected":expected,"pass":passed}
 results.append(row)
 print(("PASS " if passed else "FAIL ")+label+" actual="+str(actual)+" expected="+str(expected))
 if not passed:failures.append(row)
func reset():
 for a in [game.units,game.buildings,game.enemies]:
  for e in a:
   if is_instance_valid(e.node):e.node.queue_free()
  a.clear()
 game.selected.clear();game.effects.clear();game.upgrades.clear();game.recruit_queue.clear();game.blast_queue.clear()
 game.resources=1000;game.gathered=0;game.ammo=240;game.kills=0;game.xp=0;game.level=1;game.generator_on=false;game.power_clock=0
 game.elapsed=0;game.wave_clock=999;game.build_boost=0;game.victory_boost=0;game.ended=false;game.active_card=false
 game.noise=0;game.low_fx=true;game.muted=true
 for s in game.sites:
  s.reclaimed=false;s.progress=0;s.stock=650;s.paid=false
func grant(id:String):
 game.cards=[Catalog.by_id(id)];game.active_card=true;game.choose_upgrade(0)
func target(p:Vector3=Vector3(20,0,0),hp:float=10000)->Dictionary:
 var node=Node3D.new();game.add_child(node);node.position=p
 var e={"node":node,"hp":hp,"dead":false,"armored":false,"charged_until":0.0}
 game.enemies.append(e);return e
func step_economy(seconds:float,dt:float=.05):
 for i in roundi(seconds/dt):game.update_economy(dt)
func armor_test():
 reset()
 var guard=game.make_unit("guard",Vector3.ZERO)
 var worker=game.make_unit("worker",Vector3.ZERO)
 var truck=game.make_unit("truck",Vector3.ZERO)
 var tower=game.make_building("tower",Vector3(2,0,0),true)
 var wall=game.make_building("wall",Vector3(4,0,0),true)
 var hq=game.make_building("hq",Vector3(0,0,8),true)
 for e in [guard,worker,truck,tower,wall,hq]:e.hp=e.maxhp-50
 for rank in range(1,4):
  grant("armor")
  for e in [guard,worker,truck,tower,wall]:
   check("armor R%d %s maxhp"%[rank,e.kind],e.maxhp,e.basehp*(1+.2*rank))
   check("armor R%d %s heals increase"%[rank,e.kind],e.hp,e.basehp*(1+.2*rank)-50)
 var fresh=game.make_unit("guard",Vector3.ZERO)
 check("armor new guard inherits R3",fresh.maxhp,160)
 check("armor HQ existing maxhp (observed exclusion)",hq.maxhp,800)
func move_test():
 for kind in ["guard","worker","truck"]:
  for rank in [0,1,2,3]:
   reset();game.upgrades={"move":rank}
   var u=game.make_unit(kind,Vector3.ZERO)
   u.goal=Vector3(15,0,0);u.planned=u.goal;u.route=[];u.task="move";u.cd=999
   game.simulate(.05)
   var speed=4.4 if kind=="guard" else 4.0 if kind=="worker" else 3.5
   check("move %s R%d actual displacement"%[kind,rank],u.node.position.length(),speed*(1+.12*rank)*.05)
func supply_test():
 for kind in ["guard","tower"]:
  for rank in [0,1,2,3]:
   reset();game.upgrades={"supply":rank}
   var e=target();var before=game.ammo
   game.fire(Vector3.ZERO,e,100,kind)
   check("supply %s R%d ammo cost"%[kind,rank],before-game.ammo,1-.15*rank)
   check("supply %s R%d damage intact"%[kind,rank],10000-e.hp,100)
 reset();game.ammo=.3
 var enemy=target();game.fire(Vector3.ZERO,enemy,100,"guard")
 check("shortage damage is 40 percent",10000-enemy.hp,40)
 check("shortage retains insufficient ammo",game.ammo,.3)
func salvage_test():
 for rank in [0,1,2,3]:
  reset();game.upgrades={"salvage":rank};game.resources=0
  var worker=game.make_unit("worker",Vector3.ZERO)
  worker.target=game.get_site("scrap");worker.task="site"
  var threshold=1.2/(1+.2*rank)
  game.work_site(worker,threshold-.0001)
  check("salvage R%d no premature credit"%rank,game.resources,0)
  game.work_site(worker,.0002)
  check("salvage R%d threshold resources"%rank,game.resources,4)
  check("salvage R%d gathered"%rank,game.gathered,4)
  check("salvage R%d stock decremented"%rank,worker.target.stock,646)
 reset();game.resources=0;game.gathered=0
 var worker=game.make_unit("worker",Vector3.ZERO);worker.target=game.get_site("scrap");worker.target.stock=2
 game.work_site(worker,1.2)
 check("salvage partial stock exact payout",game.resources,2)
 check("salvage partial gathered exact",game.gathered,2)
 game.work_site(worker,1.2);check("salvage depleted no extra payout",game.resources,2)
func build_queue_test():
 for rank in [0,1,2,3]:
  reset();game.upgrades={"build":rank}
  var b=game.make_building("tower",Vector3(10,0,0),false)
  var w=game.make_unit("worker",Vector3(10,0,2));w.task="build";w.target=b;w.goal=w.node.position
  game.simulate(.05)
  check("build R%d construction progress"%rank,b.built,.05*.13*(1+.2*rank))
  game.recruit("guard");game.update_economy(.05)
  check("build R%d queued production progress"%rank,game.recruit_queue[0].time,4-.05*(1+.2*rank))
 reset();var start=game.resources
 game.recruit("guard");game.recruit("worker");game.recruit("truck")
 check("queue costs charged once",start-game.resources,155)
 game.update_economy(1)
 check("queue first job progressed",game.recruit_queue[0].time,3)
 check("queue second waits",game.recruit_queue[1].time,4)
 check("queue truck waits",game.recruit_queue[2].time,7)
 game.cancel_recruit();check("cancel last refund",game.resources,start-75)
 game.cancel_recruit();check("cancel next refund",game.resources,start-45)
 game.cancel_recruit();check("cancel partially produced refund",game.resources,start)
 game.cancel_recruit();check("cancel empty no extra refund",game.resources,start)
 game.recruit("worker");step_economy(4.05)
 check("queue completes worker",game.units.size(),1)
 check("queue completed job removed",game.recruit_queue.size(),0)
 check("queue completion kind",game.units[0].kind,"worker")
 reset();game.resources=29;game.recruit("worker")
 check("queue insufficient funds rejected",game.recruit_queue.size(),0)
 check("queue rejected funds unchanged",game.resources,29)
func power_test():
 for rank in [0,1,2,3]:
  reset();game.upgrades={"power":rank};game.generator_on=true
  var pos=game.get_site("generator").node.position
  for i in 9:game.make_building("tower",pos+Vector3(i*.1,0,0),true)
  game.recompute_power()
  check("power R%d capacity"%rank,game.power_capacity,6*(1+.15*rank))
  check("power R%d fed tower count"%rank,game.buildings.filter(func(b):return b.powered).size(),floori(6*(1+.15*rank)))
  check("power no overcommit R%d"%rank,game.power_used<=game.power_capacity,true)
 reset();game.generator_on=true
 var gen=game.get_site("generator").node.position
 var relay=game.make_building("relay",gen+Vector3(21,0,0),true)
 var far=game.make_building("tower",gen+Vector3(42,0,0),true)
 var beyond=game.make_building("tower",gen+Vector3(44,0,0),true)
 var factory=game.make_building("factory",gen,true)
 game.recompute_power()
 check("relay forwards supply",far.powered,true)
 check("power outside network false",beyond.powered,false)
 check("power factory relay tower demand",game.power_used,3.5)
 factory.enabled=false;game.recompute_power()
 check("disabled factory not powered",factory.powered,false)
 check("disabled factory power freed",game.power_used,1.5)
 game.generator_on=false;game.recompute_power()
 check("generator off capacity",game.power_capacity,0)
 check("generator off clears consumers",game.power_used,0)
func ammo_factory_test():
 reset();game.ammo=0;game.update_economy(1)
 check("passive ammo refill",game.ammo,2)
 for upgrades in [{},{"build":3},{"economy":2},{"build":3,"economy":2}]:
  reset();game.upgrades=upgrades;game.victory_boost=8;game.generator_on=true;game.ammo=0
  game.make_building("factory",game.get_site("generator").node.position,true)
  game.update_economy(1)
  var mult=1+.2*upgrades.get("build",0)+.25*upgrades.get("economy",0)
  check("factory ammo actual "+str(upgrades),game.ammo,2+8*mult)
  check("factory resource debit "+str(upgrades),game.resources,998.5)
 reset();game.generator_on=true;game.ammo=0
 var f=game.make_building("factory",game.get_site("generator").node.position,true);f.enabled=false
 game.update_economy(1);check("disabled factory no ammo output",game.ammo,2);check("disabled factory no resource debit",game.resources,1000)
 reset();game.generator_on=true;game.ammo=0;game.resources=1
 game.make_building("factory",game.get_site("generator").node.position,true)
 game.update_economy(1);check("factory insufficient resources no output",game.ammo,2);check("factory no negative resources",game.resources,1)
 reset();game.ammo=399.99;game.update_economy(1);check("ammo capped at 400",game.ammo,400)
func repair_test():
 for rank in [1,2]:
  reset();game.upgrades={"repair":rank}
  var guard=game.make_unit("guard",Vector3(0,0,8));guard.hp=20
  var tower=game.make_building("tower",Vector3(4,0,8),true);tower.hp=20
  var outside=game.make_unit("guard",Vector3(25,0,25));outside.hp=20
  game.update_economy(1)
  check("repair R%d guard actual HP"%rank,guard.hp,20+.5*rank)
  check("repair R%d tower actual HP"%rank,tower.hp,20+1.1*rank)
  check("repair R%d outside unchanged"%rank,outside.hp,20)
  guard.hp=guard.maxhp-.1;game.update_economy(1);check("repair R%d capped at maxhp"%rank,guard.hp,guard.maxhp)
 reset();game.upgrades={"repair":1}
 var truck=game.make_unit("truck",Vector3(25,0,25))
 var near=game.make_unit("guard",Vector3(25,0,20));near.hp=20
 game.update_economy(1);check("repair mobile supply outside HQ",near.hp,20.5)
 truck.node.position=Vector3(-25,0,-25);game.update_economy(1);check("repair aura leaves with truck",near.hp,20.5)
func economy_test():
 for rank in [1,2]:
  reset();game.upgrades={"economy":rank};game.kills=23
  var e=target(Vector3.ZERO,1);game.hit(e,2,true)
  check("economy R%d kill24 no burst"%rank,game.victory_boost,0)
  e=target(Vector3.ZERO,1);game.hit(e,2,true)
  check("economy R%d kill25 burst8seconds"%rank,game.victory_boost,8)
  game.recruit("guard");game.update_economy(1)
  check("economy R%d queued actual production"%rank,game.recruit_queue[0].time,4-(1+.25*rank))
  check("economy R%d remaining duration"%rank,game.victory_boost,7)
  game.kills=49;e=target(Vector3.ZERO,1);game.hit(e,2,true)
  check("economy R%d retrigger refresh"%rank,game.victory_boost,8)
  check("economy R%d no multiplier stacking"%rank,game.production_multiplier(),1+.25*rank)
  game.update_economy(8)
  check("economy R%d expires"%rank,game.victory_boost,0)
  check("economy R%d expired production"%rank,game.production_multiplier(),1)
func fortress_test():
 for kind in ["guard","tower"]:
  for inside in [true,false]:
   reset();game.upgrades={"fortress":1,"supply":1,"repair":1}
   game.make_unit("truck",Vector3.ZERO)
   var origin=Vector3(5,0,0) if inside else Vector3(20,0,0)
   var e=target(Vector3(25,0,0));var before=game.ammo
   game.fire(origin,e,100,kind)
   check("fortress %s %s damage"%[kind,inside],10000-e.hp,120 if kind=="guard" and inside else 100)
   check("fortress %s %s ammo"%[kind,inside],before-game.ammo,.75 if kind=="guard" and inside else .85)
 reset();game.upgrades={"fortress":1};var truck=game.make_unit("truck",Vector3.ZERO)
 check("fortress initially present",game.mobile_aura(Vector3(5,0,0)),true)
 truck.node.position=Vector3(25,0,25)
 check("fortress follows truck away",game.mobile_aura(Vector3(5,0,0)),false)
 check("fortress follows truck new location",game.mobile_aura(Vector3(24,0,24)),true)
func fallback_test():
 reset();game.resources=0;grant("reserve");check("reserve immediate resources",game.resources,80)
 grant("reserve2");check("reserve2 duration",game.build_boost,12);check("reserve2 construction multiplier",game.construction_multiplier(),1.5)
 game.build_boost=4;grant("reserve2");check("reserve2 refresh duration",game.build_boost,12);check("reserve2 no multiplier stacking",game.construction_multiplier(),1.5)
 var u=game.make_unit("guard",Vector3.ZERO);u.hp=1
 var b=game.make_building("tower",Vector3.ZERO,true);b.hp=1
 grant("field_repair");check("field repair unit actual HP",u.hp,u.maxhp);check("field repair building actual HP",b.hp,b.maxhp)
func run():
 root.get_node("Campaign").launch=true
 game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.muted=true;game.low_fx=true
 armor_test();move_test();supply_test();salvage_test();build_queue_test();power_test();ammo_factory_test();repair_test();economy_test();fortress_test();fallback_test()
 var data={"assertions":results.size(),"failures":failures.size(),"fixture_disclosure":"Stat fixtures directly grant ranks or select injected catalog cards, create isolated units/buildings/enemies; no full earned-resource campaign claim. Unmodified copied main.gd methods execute headlessly.","results":results}
 FileAccess.open("res://support_results.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
 print("SUPPORT_QA_DONE assertions=%d failures=%d"%[results.size(),failures.size()])
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
