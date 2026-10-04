extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.get_node("Campaign").launch=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.muted=true
 g.build_mode="factory"
 var ok=g.place_building(Vector3(5,0,12))
 var b=g.buildings.back()
 var money=g.resources
 for u in g.units:
  if u.kind=="worker" and u.task=="build":u.hp=0
 g.simulate(.05)
 g.select_workers()
 g.command_at(b.node.position)
 var resumed=false
 for u in g.units:
  if u.kind=="worker" and u.task=="build" and u.target==b:resumed=true
 print("QA_RESUME_BUILD placed=",ok," resumed=",resumed," no_double_charge=",g.resources==money)
 for i in 400:g._process(.05)
 print("QA_RESUME_BUILD_FINISHED ",b.built==1," progress=",b.built)
 quit()
