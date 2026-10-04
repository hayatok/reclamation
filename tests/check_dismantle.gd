extends SceneTree
var g
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok,msg):
 checks+=1
 if not ok:failures+=1
 print("QA_","PASS " if ok else "FAIL ",msg)
func fresh():
 if is_instance_valid(g):root.remove_child(g);g.free()
 root.get_node("Campaign").current=0;root.get_node("Campaign").launch=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.muted=true;g.resources=1000
func placed(kind="tower"):
 g.build_mode=kind
 if not g.place_building(Vector3(5,0,5)):return {}
 return g.buildings.back()
func run():
 for config in [[0.0,1.0,65],[.5,1.0,48],[1.0,1.0,32],[1.0,.5,16]]:
  fresh();var b=placed();b.built=config[0];b.hp=b.maxhp*config[1]
  check(b.paid_cost==65 and g.resources==935,"actual placement tracks paid65")
  check(g.dismantle_refund(b)==config[2],"refund progress/health "+str(config))
  var expected=935+config[2]
  check(g.dismantle_building(b) and g.resources==expected and g.resources<=1000,"dismantle cannot profit")
  check(not g.dismantle_building(b) and g.resources==expected,"duplicate dismantle cannot credit")
 fresh();var initial=g.resources;var starter=g.buildings[1]
 check(starter.paid_cost==0 and g.dismantle_refund(starter)==0,"free starter refund0")
 check(g.dismantle_building(starter) and g.resources==initial,"free starter removal grants nothing")
 check(not g.can_dismantle(g.buildings[0]) and not g.dismantle_building(g.buildings[0]),"HQ cannot dismantle")
 check(not g.can_dismantle(g.get_site("generator")) and not g.dismantle_building(g.get_site("generator")),"objective site cannot dismantle")
 fresh();var b=placed();var worker={}
 for u in g.units:
  if u.task=="build" and u.target==b:worker=u
 var cell=Vector2i(5,5)
 check(g.nav.is_point_solid(cell),"building blocks navigation")
 g.dismantle_building(b)
 check(worker.task=="idle" and worker.target==null and worker.route.is_empty(),"assigned worker released")
 check(not g.nav.is_point_solid(cell),"navigation rebuilt after removal")
 fresh();b=placed("factory");b.built=1;g.get_site("generator").reclaimed=true;g.generator_on=true;g.recompute_power();var demand=g.power_used
 g.dismantle_building(b)
 check(g.power_used==demand-2,"power allocation rebuilt after factory removal")
 fresh();b=placed();g.inspected=b;g.paused=false;var before=g.resources;var count=g.root_ui.get_child_count()
 g.request_dismantle();g.request_dismantle()
 check(g.paused and g.resources==before and b in g.buildings and g.root_ui.get_child_count()==count+1,"one dialog and no mutation before confirmation")
 g.close_dismantle()
 check(not g.paused and g.resources==before and b in g.buildings,"cancel leaves building/money and restores running state")
 await process_frame
 g.paused=true;g.inspected=b;g.request_dismantle();g.confirm_dismantle();var confirmed=g.resources;g.confirm_dismantle()
 check(g.paused and not b in g.buildings and g.resources==confirmed,"confirm preserves tactical pause and double confirmation safe")
 fresh();b=placed();b.hp=0;before=g.resources
 check(not g.dismantle_building(b) and g.resources==before,"dead building cannot refund")
 fresh();b=placed();b.built=1;g.save_checkpoint(false);g.load_checkpoint();var loaded={}
 for candidate in g.buildings:
  if candidate.node.position.distance_to(Vector3(5,0,5))<.1:loaded=candidate
 check(loaded.paid_cost==65 and g.dismantle_refund(loaded)==32,"paid cost survives save/load")
 print("DISMANTLE_SUMMARY checks=",checks," failures=",failures)
 g.queue_free();await process_frame;quit(1 if failures else 0)
