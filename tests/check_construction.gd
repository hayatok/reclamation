extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.get_node("Campaign").launch=true
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.muted=true
 game.build_mode="tower"
 assert(game.place_building(Vector3(5,0,5)))
 var building=game.buildings.back()
 var resources=game.resources
 for unit in game.units:
  if unit.kind=="worker":unit.task="idle";unit.target=null
 game.select_workers()
 game.command_at(building.node.position)
 for i in 260:game.simulate(.05)
 assert(building.built>=1,"Replacement workers can finish construction")
 assert(game.resources==resources,"Resuming construction cannot double-charge")
 print("RESUME_CONSTRUCTION_NO_DOUBLE_CHARGE_PASS")
 game.queue_free()
 await process_frame
 quit()
