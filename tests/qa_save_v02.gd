extends SceneTree
var g
func _initialize():call_deferred("run")
func check(ok,msg):print("QA_SAVE_", "PASS " if ok else "FAIL ",msg)
func run():
 root.get_node("Campaign").launch=true
 g=load("res://main.tscn").instantiate()
 root.add_child(g)
 g.set_process(false)
 g.muted=true
 g.select_workers()
 g.assign_site("generator")
 g.build_mode="wall"
 g.place_building(Vector3(5,0,5))
 g.spawn_enemy(Vector3(-20,0,0),true)
 g.ammo=83.25
 g.rerolls=1
 g.build_boost=3.2
 g.victory_boost=2.5
 g.recruit("truck")
 g.preferred_family="mobile"
 g.family_misses=2
 g.enemies[0].armored=true
 g.enemies[0].charged_until=12
 g.blast_queue=[{"pos":Vector3(1,0,2),"radius":2.3,"damage":80.0,"generation":1}]
 g.paused=true
 g.xp=g.xp_needed()
 g.offer_upgrade()
 g.save_checkpoint(false)
 var before=JSON.parse_string(FileAccess.get_file_as_string("user://checkpoint.json"))
 g.choose_upgrade(0)
 g.resources=0
 check(g.load_checkpoint(),"load valid")
 g.save_checkpoint(false)
 var after=JSON.parse_string(FileAccess.get_file_as_string("user://checkpoint.json"))
 for key in before.keys():
  check(before[key]==after[key],"roundtrip "+key)
 g.choose_upgrade(0)
 var chosen=g.upgrades.duplicate()
 g.choose_upgrade(0)
 check(chosen==g.upgrades,"no duplicate restored card application")
 var f=FileAccess.open("user://checkpoint.json",FileAccess.WRITE)
 f.store_string("broken json");f.close()
 var count=g.units.size()
 check(not g.load_checkpoint() and g.units.size()==count,"invalid JSON preserves running state")
 f=FileAccess.open("user://checkpoint.json",FileAccess.WRITE)
 f.store_string('{"version":1,"mission":0}');f.close()
 check(not g.load_checkpoint() and g.units.size()==count,"incomplete schema preserves running state")
 quit()
