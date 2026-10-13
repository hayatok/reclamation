extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 g.spawn_enemy(Vector3(6,0,8),false,true,true)
 var boss=g.enemies.back();boss.windup=1.4;boss.attack_pos=g.buildings[0].node.position;boss.node.rotation.y=PI/2
 g.camera_focus=Vector3(3,0,7);g.camera.size=50
 var tag="candidate" if g.horde_renderer.get("baked_boss")!=null else "baseline"
 var out="user://boss_visual_review/";DirAccess.make_dir_recursive_absolute(out)
 for step in 36:
  g.simulate(.05)
  if step in [0,13,28,35]:
   for frame in 4:g._process(0);await process_frame
   root.get_texture().get_image().save_png(out+tag+"_%02d.png"%step)
 var f=FileAccess.open(out+tag+"_state.json",FileAccess.WRITE);f.store_string(JSON.stringify(g.checkpoint_data(),"  "));f.close()
 print("BOSS_VISUAL ",tag," hp=",g.buildings[0].hp," windup=",boss.windup," rng=",g.rng.state)
 g.free();quit()
