extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_assault.json"));f.close()
 assert(g.load_checkpoint());g.set_process(false);g.paused=true;g.select_guards();g.selected=g.selected.filter(func(u):return u.node.position.x>0);g.update_selection();g.stop_selected()
 g.camera_focus=Vector3(54,0,-44);g.camera.size=50
 var tag="baseline" if g.combat_spacing.INFANTRY_RADIUS<.6 else "candidate"
 var initial={};for u in g.selected:initial[u.node.get_instance_id()]=u.node.position
 for tick in 20:g.simulate(.05)
 for frame in 8:g._process(0);await process_frame
 var out="user://stationary_squad_review/";DirAccess.make_dir_recursive_absolute(out)
 root.get_texture().get_image().save_png(out+tag+".png")
 var pairs=0;var maxmove=0.0
 for i in g.selected.size():
  var u=g.selected[i];maxmove=maxf(maxmove,u.node.position.distance_to(initial[u.node.get_instance_id()]))
  for j in range(i+1,g.selected.size()):
   if u.node.position.distance_to(g.selected[j].node.position)<1.33:pairs+=1
 var data={"selected":g.selected.size(),"pairs_below_ring_diameter":pairs,"max_displacement":maxmove,"elapsed":g.elapsed,"kills":g.kills,"enemies":g.enemies.size()}
 f=FileAccess.open(out+tag+".json",FileAccess.WRITE);f.store_string(JSON.stringify(data,"  "));f.close();print("SQUAD ",tag," ",data)
 g.free();quit()
