extends SceneTree
# Controlled visual/command fixture, not earned progression or a difficulty test.
const StructureVisuals=preload("res://structure_visuals.gd")
var g:Node
var out:String
func _initialize():call_deferred("run")
func settle():
 for i in 32:g._process(.05);await process_frame
func capture(name:String):
 await settle()
 root.get_texture().get_image().save_png(out+name+".png")
func tap(p:Vector2):
 for down in [true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=p;e.pressed=down
  Input.parse_input_event(e);await process_frame
func run():
 create_timer(60).timeout.connect(func():quit(2))
 out=OS.get_environment("RECLAMATION_REVIEW_OUT")
 if out.is_empty():out="user://central_station_review/"
 DirAccess.make_dir_recursive_absolute(out)
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 g.settlement_age=3;g.generator_on=true;g.hold_time=25;g.resources=100
 for site in g.sites:
  site.reclaimed=true;site.paid=true;site.progress=1
  StructureVisuals.set_site_reclaimed(site.node,true)
 var station=g.get_site("pump")
 g.assign_site("pump");g.camera.size=42
 g.spawn_enemy(station.node.position+Vector3(-6,0,0))
 for i in 160:g.simulate(.05)
 if station.has("hp"):assert(station.hp<station.maxhp)
 await capture("ordinary_attack")
 for enemy in g.enemies:enemy.node.queue_free()
 g.enemies.clear()
 var attacker={"attack_pos":station.node.position,"cd":0.0}
 g.boss_impact(attacker)
 await capture("damaged")
 for i in 4:g.boss_impact(attacker)
 g.update_mission(.05)
 await capture("stopped")
 var worker=g.units.filter(func(u):return u.kind=="worker")[0]
 worker.node.position=station.node.position+Vector3(4,0,0)
 g.selected=[worker];g.inspected_site={};g.update_selection()
 var accepted=g.command_at(station.node.position)
 assert(accepted)
 if station.has("hp"):
  assert(worker.task=="repair" and worker.target==station)
  for i in 160:g.simulate(.05)
 g.assign_site("pump")
 await capture("repairing")
 var result={"scope":"Controlled reclaimed M3 site, five direct existing boss impacts, one normal repair command; not earned play","mobile":g.mobile_enabled,"hp":station.get("hp",-1),"disabled":station.get("disabled",false),"hold":g.hold_time,"worker_task":worker.task,"repair_order_accepted":accepted}
 if g.mobile_enabled:
  Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=false
  await tap(g.mobile_hud.selection.get_global_rect().get_center());await settle()
  assert(g.mobile_hud.has_open_popup())
  await capture("mobile_details")
  g.mobile_browser._native_test_size=Vector2(390,844);g._mobile_layout();g.mobile_hud._layout();await settle()
  assert(g.mobile_hud.safe_rect.encloses(g.mobile_hud.popup.get_meta("fixed_close").get_global_rect()))
  await capture("portrait_details")
  await tap(g.mobile_hud.popup.get_meta("fixed_close").get_global_rect().get_center());await settle()
  assert(not g.mobile_hud.has_open_popup())
  result["synthetic_close"]=true
 var f=FileAccess.open(out+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("CENTRAL_STATION_REVIEW ",JSON.stringify(result));g.free();quit()
