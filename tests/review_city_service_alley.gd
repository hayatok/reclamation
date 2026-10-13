extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 g.camera_focus=Vector3(-18,0,-10);g.camera.size=42
 var out="user://city_alley_review/";DirAccess.make_dir_recursive_absolute(out)
 var pipe:Node3D
 for child in g.get_children():
  if child.get_script()==load("res://tactical_map.gd"):
   for model in child.get_children():
    if model is Node3D and model.position.is_equal_approx(Vector3(-15.5,0,-8.5)) and not model is StaticBody3D:pipe=model;break
 if pipe==null:push_error("Pipe model not found");quit(1);return
 var new_transform=pipe.transform
 pipe.position.x=-17;pipe.scale.x=1.2
 for i in 3:g._process(0);await process_frame
 root.get_texture().get_image().save_png(out+"old_pipe_visual_only.png")
 pipe.transform=new_transform
 for i in 3:g._process(0);await process_frame
 root.get_texture().get_image().save_png(out+"service_alley.png")
 g.settlement_age=3;g.generator_on=true;g.wave=4;g.wave_clock=9999;g.spawn_wave()
 var starts={};var blocked_at_spawn=0
 for e in g.enemies:
  starts[e.node.get_instance_id()]=e.node.position
  if g.nav.is_point_solid(Vector2i(roundi(e.node.position.x),roundi(e.node.position.z))):blocked_at_spawn+=1
 var corrections=0
 for i in 240:
  g.simulate(.05)
  for e in g.enemies:
   if g.nav.is_point_solid(Vector2i(roundi(e.node.position.x),roundi(e.node.position.z))):corrections+=1
 var short_movers=[];var minimum=INF
 for e in g.enemies:
  var dis=e.node.position.distance_to(starts[e.node.get_instance_id()]);minimum=minf(minimum,dis)
  if dis<1:short_movers.append([e.node.position.x,e.node.position.z])
 for i in 3:g._process(0);await process_frame
 root.get_texture().get_image().save_png(out+"late_wave_12s.png")
 var boss_source=g.city_ruin_layout.correct_spawn(g.nav,Vector3(-25,0,-18),0)
 var result={"scope":"Controlled M3 ordinary late-wave4 spawn at stageIII, generator active; not earned normal progression or balance acceptance","spawned":starts.size(),"blocked_spawn":blocked_at_spawn,"solid_cell_observations":corrections,"remaining":g.enemies.size(),"minimum_12s_displacement":minimum,"under_1m":short_movers,"boss_corrected_source":[boss_source.x,boss_source.z],"boss_route_exists":not g.enemy_route(boss_source,g.buildings[0]).is_empty(),"rng":str(g.rng.state)}
 var f=FileAccess.open(out+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print("CITY_ALLEY ",JSON.stringify(result));g.free();quit()
