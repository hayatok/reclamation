extends SceneTree
# Isolated mechanics fixtures; run with --headless --path . --script res://tests/check_v04_weapons.gd.
var g
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok,msg):
 checks+=1
 if not ok:failures+=1
 print("QA_", "PASS " if ok else "FAIL ",msg)
func close(a,b):return absf(a-b)<.001
func fresh():
 if is_instance_valid(g):root.remove_child(g);g.free()
 root.get_node("Campaign").current=0;root.get_node("Campaign").launch=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.muted=true;g.low_fx=true;g.wave_clock=9999
func enemy(p):
 g.spawn_enemy(p);var e=g.enemies.back();e.hp=1000;e.speed=0;return e
func run():
 fresh()
 g.resources=1000
 g.recruit("grenade")
 check(g.resources==1000 and g.recruit_queue.is_empty(),"grenade locked before research")
 g.set_build("mortar")
 check(g.build_mode=="","mortar mode locked before research")
 g.build_mode="mortar"
 check(not g.place_building(Vector3(5,0,12)) and g.resources==1000,"mortar placement locked no spend")
 g.start_research()
 check(not g.research_active and g.resources==1000,"research requires infrastructure")
 var factory=g.make_building("factory",Vector3(12,0,1),true)
 var yard=g.make_building("yard",Vector3(-10,0,15),true)
 g.get_site("generator").reclaimed=true;g.generator_on=true;g.recompute_power()
 check(factory.powered,"factory gets grid power")
 g.resources=179;g.start_research()
 check(not g.research_active and g.resources==179,"research insufficient resources safe")
 g.resources=1000;g.start_research();g.start_research()
 check(g.research_active and g.resources==820,"research charges once")
 for i in 599:g.update_economy(.05)
 check(g.tech_level==1,"research not early before30s")
 g.update_economy(.10)
 check(g.tech_level==2 and not g.research_active and close(g.base_power(),9),"research unlock and+3power")
 var funds=g.resources;g.recruit("grenade")
 check(g.recruit_queue.back().kind=="grenade" and close(funds-g.resources,75),"grenade queued at75")
 for i in 141:g.update_economy(.05)
 var grenade={}
 for u in g.units:
  if u.kind=="grenade":grenade=u
 check(not grenade.is_empty() and close(grenade.maxhp,120),"grenade completes7s with120hp")
 g.select_guards();check(grenade in g.selected,"combat select includes grenade")
 var worker=g.units[6];worker.node.position=Vector3(-10,0,11);worker.target=g.get_site("scrap");worker.work=0
 var stock=worker.target.stock;g.work_site(worker,1.2)
 check(close(stock-worker.target.stock,5.6),"yard boosts worker pickup40%")
 yard.powered=true;g.power_clock=100
 var gathered=g.gathered;g.update_economy(1)
 check(close(g.gathered-gathered,1.5),"powered yard auto collects1.5persec")
 fresh()
 var a=enemy(Vector3(0,0,-15));var b=enemy(Vector3(2,0,-15));var c=enemy(Vector3(3.1,0,-15))
 g.ammo=100;g.fire(Vector3(0,1,-10),a,56,"grenade")
 check(g.shells.size()==1 and a.hp==1000 and close(g.ammo,97),"grenade launches delayed shell for3ammo")
 g.update_shells(.79);check(a.hp==1000,"grenade no impact before.8s")
 g.update_shells(.02)
 check(close(a.hp,944) and close(b.hp,963.6) and c.hp==1000 and g.shells.is_empty(),"grenade primary56 splash36.4 radius3")
 var olda=a.hp;g.fire(Vector3(0,1,-10),a,56,"grenade");g.paused=true;g._process(.05)
 check(g.shells[0].time==0 and a.hp==olda,"tactical pause freezes shells")
 g.paused=false;g.upgrades={"blast_radius":2};g.launch_shell(Vector3(0,1,-10),a.node.position,85,4.1,"mortar")
 check(close(g.shells.back().radius,5.33) and close(g.shells.back().duration,1.35),"mortar delay and radius upgrade")
 fresh()
 for u in g.units:u.cd=999
 for building in g.buildings:building.cd=999
 var mortar=g.make_building("mortar",Vector3(0,0,17),true);a=enemy(Vector3(0,0,22));g.power_clock=999
 g.simulate(.05)
 check(g.shells.is_empty(),"unpowered mortar cannot shoot")
 mortar.powered=true;g.simulate(.05)
 check(g.shells.size()==1 and close(g.shells[0].damage,85) and close(mortar.cd,3.2),"powered mortar fires85 every3.2s")
 fresh()
 var truck=g.make_unit("truck",Vector3(0,0,0));g.upgrades={"fortress":1,"supply":1};a=enemy(Vector3(0,0,-5));g.ammo=100
 g.fire(Vector3(0,1,0),a,56,"grenade")
 check(close(100-g.ammo,2.25),"fortress ammo discount includes grenade squad actual="+str(100-g.ammo))
 mortar=g.make_building("mortar",Vector3(0,0,8),true);mortar.hp=100;g.upgrades={"repair":1};g.update_economy(1)
 check(close(mortar.hp,101.4),"repair includes mortar defense actual="+str(mortar.hp))
 print("QA_WEAPON_SUMMARY checks=",checks," failures=",failures)
 g.queue_free()
 await process_frame
 quit(1 if failures>0 else 0)
