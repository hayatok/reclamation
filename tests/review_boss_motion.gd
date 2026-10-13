extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 g.spawn_enemy(Vector3(10,0,8),false,true,true)
 var boss=g.enemies.back();g.camera_focus=Vector3(4,0,7);g.camera.size=50
 var out="user://boss_motion_review/";DirAccess.make_dir_recursive_absolute(out)
 for step in 24:
  g.simulate(.05)
  for frame in 2:g._process(0);await process_frame
  if step in [2,9,17,23]:root.get_texture().get_image().save_png(out+"walk_%02d.png"%step)
 g.hit(boss,10000,true)
 for step in 28:
  g.simulate(.05)
  for frame in 2:g._process(0);await process_frame
  if step in [2,9,17,27]:root.get_texture().get_image().save_png(out+"death_%02d.png"%step)
 print("BOSS_MOTION corpse_count=",g.corpses.size()," boss_dead=",g.boss_defeated)
 g.free();quit()
