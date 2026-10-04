extends SceneTree
var g
var family=""
var priority=[]
var first_card=-1.0
func _initialize():call_deferred("run")
func step(t):
 for i in int(t/.05):
  if g.active_card:
   if first_card<0:first_card=g.elapsed
   if family=="mobile" and g.rerolls>0 and g.level>=5 and g.upgrades.get("supply",0)==0 and not g.cards.any(func(card):return card.id=="supply"):
    g.reroll_cards()
   var choice=0;var best=999
   for j in g.cards.size():
    var rank=priority.find(g.cards[j].id)
    if rank<0:rank=900
    if rank<best:best=rank;choice=j
   g.choose_upgrade(choice)
  g._process(.05)
func guards(p):
 g.select_guards();g.selected=g.selected.slice(0,4);g.command_at(p)
func gather(p=Vector3(-10,0,9)):
 g.select_workers();g.command_at(p)
func workers():
 var count=0
 for u in g.units:
  if u.kind=="worker":count+=1
 while count<3 and not g.ended and g.resources>=30:
  g.recruit("worker");count+=1
 step(13)
func build(kind,p):
 if g.ended:return
 g.build_mode=kind
 var ok=g.place_building(p)
 print("BUILD ",family," ",kind," at",p," ok=",ok," t=",g.elapsed," res=",g.resources)
 if ok:
  var b=g.buildings.back()
  var until=g.elapsed+50
  while not g.ended and is_instance_valid(b.node) and b.built<1 and g.elapsed<until:
   var active=false
   for u in g.units:
    if u.kind=="worker" and u.task=="build" and u.target==b:active=true
   if not active:
    workers();g.select_workers();g.command_at(b.node.position)
   step(.5)
  print("CONSTRUCTION ",kind," progress=",b.built," t=",g.elapsed)
func run():
 var c=root.get_node("Campaign")
 var families=["lightning","explosive","mobile"]
 var priorities={
 "lightning":["storm","chain","power","damage","rate","supply","range","armor","salvage","build","repair","crit","critpower","overload","multi","pierce","economy","blast","salvo","blast_radius","move","fortress","cascade","sweep","reserve","field_repair","reserve2"],
 "explosive":["cascade","blast","blast_radius","damage","rate","supply","range","armor","salvage","build","repair","crit","critpower","overload","multi","pierce","economy","chain","salvo","move","power","fortress","storm","sweep","reserve","field_repair","reserve2"],
 "mobile":["fortress","multi","supply","repair","damage","rate","range","armor","move","salvage","build","crit","critpower","overload","pierce","economy","chain","salvo","blast","blast_radius","power","cascade","storm","sweep","reserve","field_repair","reserve2"]}
 for index in [2]:
  c.current=index;c.launch=true
  family=families[index];priority=priorities[family];first_card=-1
  g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.muted=true
  guards(g.mission.gen+Vector3(0,0,3))
  g.assign_site("generator")
  var until=g.elapsed+40
  while not g.ended and not g.get_site("generator").reclaimed and g.elapsed<until:step(1)
  guards(Vector3(0,0,3));gather();step(22)
  build("tower",Vector3(-5,0,5));build("tower",Vector3(8,0,5));build("factory",Vector3(5,0,12));gather();step(12)
  build("relay",Vector3(0,0,3))
  for extra in 4:g.recruit("guard")
  step(17)
  g.toggle_generator()
  print("GENERATOR ",family," ready=",g.generator_on," t=",g.elapsed," units=",g.units.size()," ammo=",g.ammo," power=",g.power_used,"/",g.power_capacity)
  build("factory",Vector3(-5,0,12))
  guards(Vector3(0,0,3));step(8)
  gather();step(25)
  build("tower",Vector3(5,0,-5))
  if family=="mobile":g.recruit("truck");step(8)
  workers()
  guards(g.mission.pump+Vector3(0,0,3));step(8)
  g.assign_site("pump")
  until=g.elapsed+70
  while not g.ended and not g.get_site("pump").reclaimed and g.elapsed<until:step(1)
  print("PUMP ",family," ready=",g.get_site("pump").reclaimed," t=",g.elapsed," units=",g.units.size())
  guards(Vector3(0,0,3));gather()
  while not g.ended and g.elapsed<650:
   if g.get_site("scrap").stock<=0:gather(Vector3(9,0,10))
   if family=="mobile":
    for u in g.units:
     if u.kind=="truck":
      g.selected=[u];g.command_at(Vector3(0,0,5))
   step(1)
  print("BUILD_RESULT family=",family," mission=",c.current+1," won=",g.ended and g.hold_time>=g.mission.hold," ended=",g.ended," t=",g.elapsed," hold=",g.hold_time," gathered=",g.gathered," hp=",g.buildings[0].hp," kills=",g.kills," level=",g.level," ammo=",g.ammo," resources=",g.resources," firstcard=",first_card," ranks=",g.upgrades)
  root.remove_child(g);g.queue_free();await process_frame
 quit()
