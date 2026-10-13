extends SceneTree
func _initialize():call_deferred("run")
func inside_west(p:Vector3)->bool:return p.x>=-31.3 and p.x<=-24.9 and p.z>=-14 and p.z<=0
func run():
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true;g.wave=3
 g.camera_focus=Vector3(-18,0,-7);g.camera.size=50;g.spawn_wave()
 var initial=[]
 for e in g.enemies:initial.append({"position":[e.node.position.x,e.node.position.z],"inside_shell":inside_west(e.node.position),"solid":g.nav.is_point_solid(Vector2i(roundi(e.node.position.x),roundi(e.node.position.z)))})
 var out="user://city_entry_review/";DirAccess.make_dir_recursive_absolute(out)
 var tag="candidate" if FileAccess.file_exists("res://city_ruin_layout.gd") else "baseline"
 for i in 4:g._process(0);await process_frame
 root.get_texture().get_image().save_png(out+tag+"_spawn.png")
 for i in 80:g.simulate(.05)
 for i in 4:g._process(0);await process_frame
 root.get_texture().get_image().save_png(out+tag+"_moving.png")
 var final=[]
 for e in g.enemies:final.append([e.node.position.x,e.node.position.z])
 var result={"scope":"Controlled west-wave3 spawn using ordinary spawn_wave on freshM1 seed731054; not earned campaign balance","count":initial.size(),"initial":initial,"final":final,"rng":str(g.rng.state),"wall_cell_solid":g.nav.is_point_solid(Vector2i(-25,-7))}
 var f=FileAccess.open(out+tag+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print("CITY_ENTRY ",JSON.stringify(result));g.free();quit()
