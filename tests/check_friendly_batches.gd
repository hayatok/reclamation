extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.get_node("Campaign").launch=true
 var g=load("res://main.tscn").instantiate();root.add_child(g)
 await process_frame
 g.set_process(false)
 g.horde_renderer.update_friends(g.units)
 assert(g.horde_renderer._friendly_batches.guard[0].visible_instance_count==6)
 assert(g.horde_renderer._friendly_batches.worker[0].visible_instance_count==3)
 var u=g.make_unit("grenade",Vector3(2,0,5))
 u.goal=Vector3(4,0,5)
 g.simulate(.05)
 g.horde_renderer.update_friends(g.units)
 var visual=u.node.get_meta("actor_visuals")
 var body=visual.get_meta("body")
 assert(body.global_position.distance_to(u.node.global_position)<1)
 # Dummy headless renderer does not retain MultiMesh GPU transforms. Actual
 # placement and pose are covered by the native rendered regression scene.
 for mesh in visual.find_children("*","MeshInstance3D",true,false):assert(not mesh.visible)
 assert(g.horde_renderer._friendly_batches.grenade[0].visible_instance_count==1)
 u.hp=0
 g.horde_renderer.update_friends(g.units)
 assert(g.horde_renderer._friendly_batches.grenade[0].visible_instance_count==0)
 print("FRIENDLY_BATCH_COUNTS_SKELETON_VISIBILITY_DEATH_PASS")
 g.queue_free();await process_frame;quit()
