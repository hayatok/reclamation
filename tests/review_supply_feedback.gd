extends SceneTree
var g
var output="user://supply_review"
func _initialize():call_deferred("run")
func capture(suffix:String):
 g.update_ui();g.refresh_context_commands()
 if is_instance_valid(g.mobile_hud):g.mobile_hud.sync()
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+suffix+".png")
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_critical_factory.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 g.select_guards();g.camera_focus=Vector3(0,0,8);g._process(0)
 await capture("_quiet")
 # Explicit presentation fixture: observed event buckets and current stock are
 # controlled, not an earned-resource playthrough or a balance benchmark.
 for b in g.buildings:
  if b.kind=="factory":b.enabled=false;b.production_state="手動停止"
 for second in 13:
  g.supply_feedback.record_supply(2,"base");g.supply_feedback.record_combat_spend(10);g.supply_feedback.finish_step(1)
 g.ammo=294.8
 await capture("_deficit")
 if is_instance_valid(g.mobile_hud):
  g.mobile_hud._show_selection();await capture("_details");g.mobile_hud._close_popup()
 g.supply_feedback.reset();g.ammo=0
 for second in 3:
  g.supply_feedback.record_reserve_shot();g.supply_feedback.finish_step(1)
 await capture("_reserve")
 for second in 3:
  g.supply_feedback.record_supply(2,"base");g.supply_feedback.finish_step(1)
 g.ammo=6
 await capture("_recovered")
 print("SUPPLY_REVIEW_COMPLETE controlled presentation fixture; mobile=",g.mobile_enabled," size=",root.get_visible_rect().size)
 quit()
