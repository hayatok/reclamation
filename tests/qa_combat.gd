extends SceneTree
var g
var fails=0
var checks=0
func _initialize():call_deferred("run")
func check(ok,msg):
 checks+=1
 if not ok:fails+=1
 print("QA_", "PASS " if ok else "FAIL ",msg)
func close(a,b):return absf(a-b)<.001
func reset(ranks={}):
 for e in g.enemies:e.node.queue_free()
 g.enemies.clear();g.blast_queue.clear();g.upgrades=ranks;g.ammo=400;g.noise=0;g.kills=0;g.xp=0;g.active_card=false;g.elapsed=0
func enemy(p,hp=1000.0):
 g.spawn_enemy(p)
 var e=g.enemies.back();e.hp=hp
 return e
func shot(ranks,base=100.0):
 reset(ranks)
 var e=enemy(Vector3(0,0,-8))
 g.fire(Vector3(0,1,0),e,base,"guard")
 return 1000-e.hp
func run():
 root.get_node("Campaign").launch=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.muted=true
 check(close(shot({"damage":2}),140),"damage rank2 +40%")
 check(close(shot({"overload":1}),100),"overload inactive below60")
 reset({"overload":2});g.noise=60
 var e=enemy(Vector3(0,0,-8));g.fire(Vector3(0,1,0),e,100,"guard")
 check(close(1000-e.hp,130),"overload rank2 active +30%")
 var seed_value=0
 for i in 1000:
  g.rng.seed=i
  if g.rng.randf()<.1:seed_value=i;break
 reset({"crit":1});e=enemy(Vector3(0,0,-8));g.rng.seed=seed_value;g.fire(Vector3(0,1,0),e,100,"guard")
 check(close(1000-e.hp,150),"crit10pt confirmed seeded hit1.5x")
 reset({"crit":1,"critpower":2});e=enemy(Vector3(0,0,-8));g.rng.seed=seed_value;g.fire(Vector3(0,1,0),e,100,"guard")
 check(close(1000-e.hp,200),"critpower rank2 multiplier2x")
 reset({"multi":2});e=enemy(Vector3(0,0,-8));var a=enemy(Vector3(2,0,-8));var b=enemy(Vector3(-2,0,-8));g.fire(Vector3(0,1,0),e,100,"guard")
 check(close(a.hp,935) and close(b.hp,935),"multi rank2 two65%extra shots")
 reset({"chain":1});e=enemy(Vector3(0,0,-8));a=enemy(Vector3(2,0,-8));b=enemy(Vector3(4,0,-8));g.fire(Vector3(0,1,0),e,100,"guard")
 check(close(a.hp,935) and close(b.hp,957.75),"chain two hops65/42.25")
 reset({"chain":1,"storm":1});e=enemy(Vector3(0,0,-8));a=enemy(Vector3(2,0,-8));b=enemy(Vector3(4,0,-8));var c=enemy(Vector3(6,0,-8));a.charged_until=4;g.fire(Vector3(0,1,0),e,100,"guard")
 check(close(a.hp,918.75) and close(c.hp,972.5375),"storm extra hop and1.25electric vulnerability")
 reset({"pierce":2});e=enemy(Vector3(0,0,-8));a=enemy(Vector3(0,0,-11));b=enemy(Vector3(0,0,-13));g.fire(Vector3(0,3.3,0),e,100,"tower")
 check(close(a.hp,900) and close(b.hp,900),"tower pierce rank2 hits two aligned targets hp="+str([a.hp,b.hp]))
 reset({"blast":1});e=enemy(Vector3(0,0,-8),45);a=enemy(Vector3(1,0,-8));g.fire(Vector3(0,1,0),e,100,"guard");g.drain_blast_queue()
 check(close(a.hp,960),"blast rank1 40%")
 reset({"blast":2,"blast_radius":1});e=enemy(Vector3(0,0,-8),45);a=enemy(Vector3(2.2,0,-8));g.fire(Vector3(0,1,0),e,100,"guard");g.drain_blast_queue()
 check(close(a.hp,940),"blast rank2 60% radiusrank1 extends2to2.3")
 reset({"blast":1,"cascade":1});e=enemy(Vector3(0,0,-8),45);a=enemy(Vector3(0,0,-9.5),30);b=enemy(Vector3(0,0,-11),15);c=enemy(Vector3(0,0,-12.5),15);g.fire(Vector3(0,1,0),e,100,"guard");g.drain_blast_queue()
 check(e.dead and a.dead and b.dead and not c.dead and g.blast_queue.is_empty(),"cascade dies at second generation")
 reset({"salvo":1});e=enemy(Vector3(0,0,-8));var tower=g.buildings[1];tower.shots=0
 for i in 6:g.fire(Vector3(0,3.3,0),e,10,"tower",tower)
 check(close(e.hp,930),"salvo6shots adds one100%hit hp="+str(e.hp))
 reset({"sweep":1});var targets=[]
 for i in 7:targets.append(enemy(Vector3(0,0,-5-i*2)))
 g.salvo(Vector3(0,3.3,0),Vector3(0,0,-5),100)
 var hitcount=0
 for target in targets:
  if target.hp<1000:hitcount+=1
 check(hitcount==6,"sweep hits6collinear targets count="+str(hitcount))
 reset({"rate":1})
 for unit in g.units:unit.cd=999
 for building in g.buildings:building.cd=999
 var guard=g.units[0];guard.node.position=Vector3(0,0,0);guard.goal=guard.node.position;guard.cd=0;e=enemy(Vector3(0,0,-5))
 g.simulate(.05)
 check(close(guard.cd,.72/1.15),"rate cooldown rank1")
 reset({})
 for unit in g.units:unit.cd=999
 guard.node.position=Vector3(0,0,0);guard.goal=guard.node.position;guard.cd=0;e=enemy(Vector3(0,0,-11.3))
 g.simulate(.05);var before=e.hp
 g.upgrades={"range":1};guard.cd=0;g.simulate(.05)
 check(before==1000 and e.hp<before,"range rank1 reaches11.3m")
 print("QA_COMBAT_SUMMARY checks=",checks," fails=",fails)
 quit()
