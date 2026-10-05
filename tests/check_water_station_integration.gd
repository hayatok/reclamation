extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func fresh(index:int):
 if is_instance_valid(g):g.free()
 var campaign=root.get_node("Campaign");campaign.current=index;campaign.launch=true;campaign.resume=false;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
func run():
 fresh(0)
 var pump=g.get_site("pump");var position:Vector3=pump.node.position
 var visual=pump.node.get_node_or_null("WaterStationVisual")
 assert(visual!=null and visual.position==Vector3.ZERO)
 assert(not visual.has_node("RestoredFlowLens"))
 var cells=[]
 for x in range(-20,-8):
  for z in range(-13,-1):cells.append(g.nav.is_point_solid(Vector2i(x,z)))
 # Reach a real reserved work position before exercising the completion hook.
 g.settlement_age=3;g.tech_level=3;g.stockpile={"food":220.0,"salvage":300.0,"parts":100.0};g.resources=300.0
 var worker=g.units.filter(func(u):return u.kind=="worker")[0]
 g.selected=[worker];g.inspected={};g.command_at(pump.node.position)
 for step in 1000:
  g.simulate(.05)
  if g.friendly_navigation.is_work_arrived(worker,g.nav):break
 assert(g.friendly_navigation.is_work_arrived(worker,g.nav))
 pump.progress=.999
 g.work_site(worker,1)
 assert(pump.reclaimed and visual.get_node("RestoredFlowLens").visible)
 assert(pump.node.position==position and g.stockpile.salvage==0 and g.stockpile.parts==0)
 var after=[]
 for x in range(-20,-8):
  for z in range(-13,-1):after.append(g.nav.is_point_solid(Vector2i(x,z)))
 assert(cells==after)
 assert(g.save_checkpoint(false)==OK and g.load_checkpoint())
 pump=g.get_site("pump");assert(pump.reclaimed and pump.node.get_node("WaterStationVisual/RestoredFlowLens").visible)
 print("WATER_STATION_REAL_RESTORATION_SAVE_VISUAL_NO_NAV_CHANGE_PASS")
 fresh(1);assert(not g.get_site("pump").node.has_node("WaterStationVisual"));assert(g.get_site("pump").node.has_node("RailYard_site_rail_depot"))
 fresh(2);assert(not g.get_site("pump").node.has_node("WaterStationVisual"));assert(g.get_site("pump").node.has_node("CentralStationVisual"))
 print("MISSION_APPROPRIATE_WATER_FREIGHT_POWER_ART_PASS")
 g.free();await process_frame;quit()
