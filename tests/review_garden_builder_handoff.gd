extends SceneTree
func _initialize():call_deferred("run")
func run():
 var out=OS.get_environment("GARDEN_OUTPUT_DIR")
 if out.is_empty():out="user://garden_review"
 DirAccess.make_dir_recursive_absolute(out)
 var rows=[]
 for variant in ["before","after"]:
  var baseline=OS.get_environment("GARDEN_BASELINE_MAIN")
  if variant=="before" and baseline.is_empty():continue
  DirAccess.make_dir_recursive_absolute("user://settlement_v2")
  var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/freight_scout_3.json"));f.close()
  var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
  var g:Node
  if variant=="before":
   var script=GDScript.new();script.source_code=FileAccess.get_file_as_string(baseline)
   if script.reload()!=OK:quit(1);return
   g=Node3D.new();g.set_script(script)
  else:g=load("res://main.tscn").instantiate()
  root.add_child(g);g.set_process(false);g.paused=false
  var workers=g.units.filter(func(u):return u.kind=="worker")
  var builders=[workers[4],workers[5]]
  var hq=g.buildings.filter(func(b):return b.kind=="hq")[0]
  g.production.queue_unit(hq,"worker");g.production.queue_unit(hq,"worker")
  g.selected=builders;g.set_build("garden")
  if not g.place_building(Vector3(-77.49530029296875,0,43.11811447143555)):push_error("Garden placement failed");quit(1);return
  var garden=g.buildings.back();var initial_food=float(g.stockpile.food);var start_time=g.elapsed
  var completed_at=-1.0
  for step in 800:
   if g.active_card:g.postpone_growth_choice()
   g.advance_simulation_time(.05)
   if garden.built>=1 and completed_at<0:completed_at=g.elapsed-start_time
  g.paused=true;g.selected=builders;g.inspected={};g.camera_focus=Vector3(-73,0,43);g.camera.size=38
  g.set_process(true);g.update_selection();g.update_ui()
  for frame in 10:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out.path_join(variant+".png"))
  var info={"variant":variant,"elapsed":g.elapsed,"completed_after_seconds":completed_at,"food_before":initial_food,"food_after":g.stockpile.food,"builders":[]}
  for w in builders:info.builders.append({"task":w.task,"phase":w.economy_phase,"resource":w.resource_kind,"cargo":w.cargo,"cargo_kind":w.cargo_kind,"position":g.vec_data(w.node.position)})
  rows.append(info)
  f=FileAccess.open(out.path_join(variant+"_state.json"),FileAccess.WRITE);f.store_string(JSON.stringify(g.checkpoint_data()));f.close()
  g.free()
 var f=FileAccess.open(out.path_join("comparison.json"),FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
 print("GARDEN_NATIVE_COMPARISON ",JSON.stringify(rows));quit()
