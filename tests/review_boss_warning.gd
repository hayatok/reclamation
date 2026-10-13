extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 g.spawn_enemy(Vector3(6,0,8),false,true,true)
 var boss=g.enemies.back();boss.windup=1.4;boss.attack_pos=Vector3(3,0,8)
 g.camera_focus=Vector3(3,0,7);g.camera.size=50
 var out="user://boss_warning_review/";DirAccess.make_dir_recursive_absolute(out)
 g._process(.4)
 for i in 3:await process_frame
 root.get_texture().get_image().save_png(out+"candidate_early.png")
 for i in 5:g._process(.3);await process_frame
 root.get_texture().get_image().save_png(out+"candidate_paused.png")
 var before={"windup":boss.windup,"pulse_count":g.effects.filter(func(e):return e.kind=="pulse").size(),"paused":g.paused,"warning_count":g.boss_attack_warning.get_debug_state().visible_count}
 var saved=g.save_checkpoint(false);g.free();await process_frame
 c.resume=true;c.launch=true
 var fresh=load("res://main.tscn").instantiate();root.add_child(fresh);current_scene=fresh;fresh.set_process(false);fresh.paused=true
 for i in 4:fresh._process(0);await process_frame
 root.get_texture().get_image().save_png(out+"candidate_resume.png")
 var bosses=fresh.enemies.filter(func(e):return e.get("boss",false))
 var result={"save_error":saved,"paused":before,"after_reload":{"boss_count":bosses.size(),"windup":bosses[0].windup if not bosses.is_empty() else -1,"pulse_count":fresh.effects.filter(func(e):return e.kind=="pulse").size(),"warning_count":fresh.boss_attack_warning.get_debug_state().visible_count}}
 var hp_before=fresh.buildings[0].hp
 for i in 28:fresh.simulate(.05)
 fresh._process(0)
 result["impact"]={"hp_before":hp_before,"hp_after":fresh.buildings[0].hp,"warning_count":fresh.boss_attack_warning.get_debug_state().visible_count,"windup":bosses[0].windup}
 bosses[0].windup=.7;fresh.update_boss_attack_warning()
 var started=Time.get_ticks_usec()
 for i in 2000:fresh.update_boss_attack_warning()
 result["cached_sync_mean_usec"]=float(Time.get_ticks_usec()-started)/2000.0
 fresh.hit(bosses[0],10000,true);fresh.update_boss_attack_warning()
 result["death_warning_count"]=fresh.boss_attack_warning.get_debug_state().visible_count
 var f=FileAccess.open(out+"candidate.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print("WARNING_CANDIDATE ",JSON.stringify(result));fresh.free();quit()
