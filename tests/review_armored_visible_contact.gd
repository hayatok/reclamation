extends SceneTree
## Controlled main-scene art comparison, not an earned campaign encounter.
## Three ordinary armored enemies are deliberately spawned; subsequent movement,
## attacks, damage and death use unmodified game rules and simulation.
var g:Node
func _initialize():call_deferred("run")
func run():
 var out=OS.get_environment("HEAVY_REVIEW_OUTPUT")
 DirAccess.make_dir_recursive_absolute(out)
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.run_seed=71221;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=false
 if OS.get_environment("HEAVY_OLD_FALLBACK")=="1":g.horde_renderer.baked_armored.active=false;g.horde_renderer.baked_armored.visible=false
 g.camera_focus=Vector3(0,0,2);g.camera.position=g.camera_focus+Vector3(37,48,43);g.camera.look_at(g.camera_focus);g.camera.size=50
 g.select_guards()
 var spawn_points=[Vector3(-7,0,2),Vector3(-8,0,3),Vector3(-7,0,4)]
 for point in spawn_points:
  assert(not g.nav.is_point_solid(Vector2i(roundi(point.x),roundi(point.z))),"Controlled spawn must be on traversable terrain")
  assert(not g.enemy_navigation.route_now(g.nav,point,g.selected[0]).is_empty(),"Controlled encounter must have a real approach route")
  g.spawn_enemy(point,false,true)
 if "--probe" in OS.get_cmdline_user_args():print("HEAVY_ENCOUNTER_PATHS_PASS");g.free();quit();return
 var rows=[]
 for frame in 300:
  if g.active_card:g.postpone_growth_choice()
  g._process(1.0/30)
  if frame<140:continue
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out.path_join("frame_%04d.png"%frame))
  rows.append({"frame":frame,"elapsed":g.elapsed,"kills":g.kills,"ammo":g.ammo,"enemies":g.enemies.map(func(e):return {"pos":g.vec_data(e.node.position),"hp":e.hp,"attack_at":e.get("attack_at",-1)}),"guards":g.units.filter(func(u):return u.kind=="guard").map(func(u):return {"pos":g.vec_data(u.node.position),"hp":u.hp}),"corpse_count":g.corpses.size()})
 var f=FileAccess.open(out.path_join("frames.json"),FileAccess.WRITE);f.store_string(JSON.stringify(rows));f.close()
 print("HEAVY_CONTROLLED_COMBAT_DONE ",JSON.stringify(rows.back()));quit()
