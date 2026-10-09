extends SceneTree
var g
var report={"orders":[],"deposits":[],"cards":[]}
func _initialize():call_deferred("run")
func log_event(name:String):report.orders.append({"time":g.elapsed,"event":name});print(name," t=",g.elapsed)
func step(seconds:float):
 for i in int(seconds/.05):
  if g.ended:return
  if g.active_card:
   report.cards.append(g.cards[0].id);g.choose_upgrade(0)
  var delivery=[]
  for u in g.units:
   var d=u.get("dropoff_target")
   if u.kind=="worker" and u.get("cargo",0)>0 and d is Dictionary and d.get("kind","")=="depot":delivery.append([u,u.cargo,u.cargo_kind])
  g.simulate(.05)
  for item in delivery:
   if item[0] in g.units and item[0].cargo<.001:report.deposits.append({"time":g.elapsed,"amount":item[1],"resource":item[2]})
func save_named(name:String):
 var file=FileAccess.open(OS.get_environment("DEPOT_EVIDENCE")+"/"+name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(g.checkpoint_data()));file.close()
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(4451)
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=false
 var workers=g.units.filter(func(u):return u.kind=="worker")
 for i in range(2,6):
  g.selected=[workers[i]];g.command_at(Vector3(-72,0,51) if i<5 else Vector3(-56,0,51))
 step(3) # Let the assigned gatherers clear the construction pad.
 g.selected=[workers[0],workers[1]];g.build_mode="barracks"
 if not g.place_building(Vector3(-66,0,57)):print("PREP_BUILD_FAILED ",g.placement_issue("barracks",Vector3(-66,0,57)));quit(2);return
 var barracks=g.buildings.back();log_event("paid training shelter")
 while barracks.built<1 and g.elapsed<60:step(.5)
 g.inspected=barracks;g.recruit("guard");g.recruit("guard");log_event("queued two paid guards")
 while g.units.filter(func(u):return u.kind=="guard").size()<4 and g.elapsed<120:step(.5)
 var guards=g.units.filter(func(u):return u.kind=="guard")
 if guards.size()!=4:print("PREP_TRAIN_FAILED");quit(2);return
 g.selected=[workers[0],workers[1]];g.command_at(guards[0].node.position)
 g.selected=guards;g.attack_move=true;g.command_at(Vector3(-50,0,-8));log_event("four guards advance, two workers follow")
 while g.elapsed<150:
  step(.5)
  if guards[0] not in g.units:break
  var local=g.enemies.filter(func(e):return not e.dead and e.node.position.distance_to(Vector3(-50,0,-8))<22)
  if guards[0].node.position.distance_to(Vector3(-50,0,-8))<10 and local.is_empty():break
 var site=g.get_site("abandoned_depot")
 save_named("earned_before_repair")
 g.selected=[workers[0],workers[1]].filter(func(u):return u in g.units);g.command_at(site.node.position);log_event("workers restore discovered depot")
 while not site.reclaimed and g.elapsed<210 and not g.ended:step(.5)
 report.restored=site.reclaimed
 if site.reclaimed:
  log_event("depot ready");save_named("earned_repaired")
  g.selected=[workers[0],workers[1]].filter(func(u):return u in g.units);g.command_at(Vector3(-52,0,-14))
  while report.deposits.is_empty() and g.elapsed<240 and not g.ended:step(.5)
  save_named("earned_delivery")
 report.elapsed=g.elapsed;report.units=g.units.size();report.hq_hp=g.buildings[0].hp;report.ended=g.ended;report.stockpile=g.stockpile;report.kills=g.kills
 var f=FileAccess.open(OS.get_environment("DEPOT_EVIDENCE")+"/play_summary.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("DEPOT_EARNED_PLAY ",JSON.stringify(report))
 g.free();await process_frame;quit(0 if report.restored and not report.deposits.is_empty() else 1)
