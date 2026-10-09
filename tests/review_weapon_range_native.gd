extends SceneTree
var g:Node
var output:String
func _initialize():call_deferred("run")
func run():
 output=OS.get_environment("RANGE_REVIEW_OUTPUT")
 if output.is_empty():output="user://weapon_range_review"
 DirAccess.make_dir_recursive_absolute(output)
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 var fixture=OS.get_environment("RANGE_REVIEW_FIXTURE")
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_siege_escort.json" if fixture.is_empty() else fixture));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 assert(not g.title_open)
 var siege:Dictionary=g.units.filter(func(u):return u.kind=="siegecart")[0]
 g.selected=[siege];g.inspected={};g.camera_focus=siege.node.position+Vector3(9,0,-5);g.camera.size=50
 g.camera.position=g.camera_focus+Vector3(37,48,43);g.camera.look_at(g.camera_focus)
 g.render_interpolation.reset(g.units,g.enemies,g.corpses)
 var frames=g.render_actors();g.resolve_shell_muzzles(frames)
 g.update_selection();g.update_ui();g.update_weapon_range_preview(frames)
 var checkpoint=g.checkpoint_data();var label=g.supply_status.text
 for variant in ["before","after"]:
  g.weapon_range_preview.visible=variant=="after"
  g.supply_status.text=label if variant=="after" else label.split("  射程")[0]
  for frame in 8:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join(variant+".png"))
  assert(g.checkpoint_data()==checkpoint)
 var report={"elapsed":g.elapsed,"state_equal":true,"selected":"siegecart","radius":g.selected_weapon_range(siege),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"label":g.supply_status.text}
 f=FileAccess.open(output.path_join("native.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 g.set_process(true)
 print("RANGE_NATIVE_READY ",JSON.stringify(report))
