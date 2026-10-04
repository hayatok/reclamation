extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.get_node("Campaign").launch=true
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false)
 var world=game.district_art
 assert(world.occlusion_buildings.size()==8)
 var actor=Node3D.new();game.add_child(actor);actor.position=Vector3(8,0,-28)
 var targets=[{"node":actor,"dead":false}]
 game.battle_visibility.update_visibility(game.camera,[],targets,[],.6)
 var faded=0
 for value in game.battle_visibility.opacity:
  if value<.9:faded+=1
 assert(faded>0 and faded<8)
 game.battle_visibility.update_visibility(game.camera,[],[],[],2)
 for value in game.battle_visibility.opacity:assert(is_equal_approx(value,1.0))
 for entry in world.occlusion_buildings:
  for mat in entry.materials:assert(mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED)
 print("OCCLUDED_ONLY_FADE_AND_OPAQUE_RESTORATION_PASS count=",faded)
 game.queue_free();await process_frame;quit()
