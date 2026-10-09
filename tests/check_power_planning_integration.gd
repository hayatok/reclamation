extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 g.settlement_age=2;g.generator_on=true;g.get_site("generator").reclaimed=true
 var generator=g.get_site("generator").node.position
 var inside=g.make_building("factory",generator+Vector3(-12,0,0),true)
 var outside=g.make_building("factory",generator+Vector3(-24,0,0),true)
 g.recompute_power();g.selected=[];g.inspected=outside
 var saved=g.checkpoint_data()
 g.update_power_planning_preview();g.update_ui()
 assert(saved==g.checkpoint_data());assert(g.power_building_status(outside)=="送電範囲外")
 assert(g.factory_status(outside)=="未給電")
 assert(g.power_coverage_preview.visible)
 g.inspected=inside;g.update_power_planning_preview()
 assert(g.power_building_status(inside)=="補給満杯" or g.power_building_status(inside)=="生産中")
 g.active_card=true;g.update_power_planning_preview();assert(not g.power_coverage_preview.visible);g.active_card=false
 g.generator_on=false;g.update_power_planning_preview();assert(g.power_context_text=="送電更新待ち" and not g.power_coverage_preview.visible)
 g.recompute_power();assert(g.power_building_status(inside)=="発電停止中")
 g.generator_on=true;g.recompute_power();g.inspected={};g.build_mode="relay";g.mobile_enabled=true
 saved=g.checkpoint_data();g.update_power_planning_preview()
 assert(g.power_coverage_preview.visible and g.power_build_hint.contains("必要"));assert(saved==g.checkpoint_data())
 var samples=[]
 for i in 300:
  var started=Time.get_ticks_usec();g.update_power_planning_preview();samples.append(Time.get_ticks_usec()-started)
 samples.sort()
 print("POWER_PREVIEW_CPU_USEC median=",samples[150]," p95=",samples[285]," geometry=",g.power_coverage_preview.debug_state())
 g.build_mode="";g.update_power_planning_preview();assert(not g.power_coverage_preview.visible)
 # Unpowered legal construction remains available: this is advice, not a gate.
 g.mobile_enabled=false;g.selected=[g.units.filter(func(u):return u.kind=="worker")[0]];g.inspected={}
 g.build_mode="relay"
 var candidate=Vector3.INF
 for x in range(-25,26,3):
  for z in range(-25,26,3):
   var point=Vector3(x,0,z)
   if g.placement_issue("relay",point).is_empty() and g.power_planning.query(g,"relay",point).status=="out_of_range" and g.construction_reachable("relay",point,g.selected):candidate=point;break
  if candidate.is_finite():break
 assert(candidate.is_finite())
 var old_salvage=float(g.stockpile.salvage);var old_parts=float(g.stockpile.parts);var old_count=g.buildings.size()
 assert(g.place_building(candidate))
 assert(g.buildings.size()==old_count+1 and g.stockpile.salvage==old_salvage-50 and g.stockpile.parts==old_parts-15)
 assert(g.selected[0].task=="build")
 print("POWER_MAIN_INTEGRATION_PASS: committed source rendering, factual reason, canonical factory status, stale OFF transition, modal, mobile build context, no saved-state mutation")
 g.free();await process_frame;quit()
