extends SceneTree
## Focused minimap dispatch fixture. Uses isolated user data and never saves.
const Orders=preload("res://worker_orders.gd")
var g:Node
var checks:int=0
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)
func choose(values:Array,building:Dictionary={}):
 g.selected=values.duplicate();g.inspected=building;g.inspected_resource={};g.inspected_site={};g.update_selection()
func local_position(point:Vector3)->Vector2:
 return (Vector2(point.x,point.z)+Vector2(32,32))/64*g.minimap.size
func map_click(point:Vector3,button:int=MOUSE_BUTTON_RIGHT,append:bool=false,pressed:bool=true):
 var event=InputEventMouseButton.new()
 event.position=local_position(point);event.button_index=button;event.shift_pressed=append;event.pressed=pressed
 g.minimap.gui_input.emit(event)
func viewport_click(point:Vector3,button:int,append:bool=false):
 var position:Vector2=g.minimap.global_position+local_position(point)
 for down in [true,false]:
  var event=InputEventMouseButton.new()
  event.position=position;event.global_position=position;event.button_index=button;event.pressed=down;event.shift_pressed=append
  root.push_input(event,true)
 await process_frame
func state(unit:Dictionary)->Dictionary:
 return {"task":unit.task,"goal":unit.goal,"target":unit.target,"pending":Orders.snapshot(g,unit),"camera":g.camera_focus,"selected":g.selected.duplicate(),"inspected":g.inspected,"attack_move":g.attack_move,"build_mode":g.build_mode,"ghost":g.ghost.visible,"ring_time":g.minimap_order_time,"ring_point":g.minimap_order_point}
func run():
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true;campaign.run_seed=20261005
 root.size=Vector2i(1440,900)
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.muted=true;g.audio_system.set_muted(true);g.active_card=false;g.title_open=false;g.ended=false
 for collection in [g.units,g.enemies,g.resource_nodes,g.sites]:
  for item in collection:
   if is_instance_valid(item.node):item.node.queue_free()
  collection.clear()
 g.selected.clear()
 for building in g.buildings.duplicate():
  if building.kind!="hq":g.buildings.erase(building);building.node.queue_free()
 g.buildings[0].node.position=Vector3(-25,0,25)
 g.terrain_blocks.clear();g.rebuild_navigation()
 var worker:Dictionary=g.make_unit("worker",Vector3(-4,0,8))
 var guard:Dictionary=g.make_unit("guard",Vector3(4,0,8))
 var ally:Dictionary=g.make_unit("guard",Vector3(-12,0,-8))
 var resource:Dictionary=g.make_resource("parts",Vector3(-18,0,-18),1000)
 var building:Dictionary=g.make_building("barracks",Vector3(-12,0,16))
 g.make_site("generator",Vector3(24,0,24))
 g.make_site("pump",Vector3(16,0,16))
 var site:Dictionary=g.sites.back()
 g.spawn_enemy(Vector3(12,0,-8));var enemy:Dictionary=g.enemies.back()
 enemy.speed=0.0;enemy.cd=100000
 await process_frame;await process_frame
 check(g.minimap.size.x>0 and g.minimap.size.y>0,"laid-out minimap provides usable dimensions")

 # Left pan keeps the current order and selection, including in build mode.
 choose([worker]);g.command_at(Vector3(-16,0,4));var before=state(worker)
 map_click(Vector3(24,0,-24),MOUSE_BUTTON_LEFT)
 check(g.camera_focus==Vector3(18,0,-18),"left minimap click maps X/Z and clamps camera bounds")
 check(worker.task==before.task and worker.goal==before.goal and g.selected==before.selected,"left pan preserves selection and active order")
 g.build_mode="house";g.ghost.visible=true;map_click(Vector3(5,0,6),MOUSE_BUTTON_LEFT)
 check(g.camera_focus.is_equal_approx(Vector3(5,0,6)) and g.build_mode=="house" and g.ghost.visible,"left map pan retains active building placement")
 before=state(worker);map_click(Vector3(20,0,-16),MOUSE_BUTTON_RIGHT,true)
 check(g.build_mode.is_empty() and not g.ghost.visible and worker.task==before.task and worker.goal==before.goal and Orders.pending(worker).is_empty(),"right map click during placement only cancels the ghost, including with Shift")

 # Right commands never move the camera or change selected actors.
 var camera_before:Vector3=g.camera_focus
 map_click(Vector3(20,0,-16))
 check(worker.task=="move" and worker.goal.is_equal_approx(Vector3(18.35,0,-16)),"right map click issues existing formation move at mapped world point")
 check(g.camera_focus==camera_before and g.selected==[worker],"right map order preserves camera and selection")
 check(g.minimap_order_time==.65 and g.minimap_order_point.is_equal_approx(Vector2(20,-16)),"accepted minimap move shows short ring at its world destination")
 map_click(resource.node.position)
 check(worker.task=="gather" and worker.resource_target==resource,"right map resource click assigns gathering")
 var active_goal:Vector3=worker.goal
 map_click(Vector3(20,0,-16),MOUSE_BUTTON_RIGHT,true)
 check(worker.task=="gather" and worker.resource_target==resource and worker.goal==active_goal and Orders.pending(worker).size()==1,"Shift map order appends without interrupting active gather")
 check(Orders.pending(worker).size()==1 and Orders.pending(worker)[0].task=="move" and Orders.pending(worker)[0].goal.is_equal_approx(Vector3(18.35,0,-16)),"Shift queue stores mapped world destination")
 map_click(building.node.position)
 check(worker.task=="build" and worker.target==building and Orders.pending(worker).is_empty(),"normal map build replaces old worker queue")
 building.built=1.0;building.hp-=10;map_click(building.node.position)
 check(worker.task=="repair" and worker.target==building,"right map damaged-building click assigns repair")
 map_click(site.node.position)
 check(worker.task=="site" and worker.target==site,"right map restoration site uses existing work resolver")
 g.minimap_order_time=0;before=state(worker);map_click(site.node.position,MOUSE_BUTTON_RIGHT,true)
 check(state(worker)==before,"unsupported Shift site order leaves current work unchanged and emits no acceptance ring")

 choose([guard]);map_click(enemy.node.position)
 check(guard.task=="focus_fire" and guard.target==enemy,"right map enemy click selects target using world distance")
 check(g.minimap_order_time==.65 and g.minimap_order_color==g.RED,"accepted enemy focus shows combat-color ring")
 var attack_destination:Vector3=enemy.node.position+Vector3(.5,0,.2)
 g.begin_attack_move();map_click(attack_destination)
 check(guard.task=="attack_move" and guard.target==null and guard.goal.is_equal_approx(attack_destination+Vector3(-1.65,0,0)) and not g.attack_move,"explicit attack-move near an enemy retains the mapped destination instead of focus fire")
 map_click(ally.node.position)
 check(guard.task=="escort" and guard.target==ally,"right map friendly click assigns escort using world distance")
 g.attack_move=true;map_click(ally.node.position)
 check(guard.task=="attack_move" and guard.target==null and not g.attack_move,"armed attack-move survives map dispatch and overrides friendly escort")
 check(g.camera_focus==camera_before and g.selected==[guard],"combat map commands preserve camera and selection")
 choose([],building);map_click(Vector3(20,0,-16))
 check(building.rally.is_equal_approx(Vector3(20,0,-16)) and g.inspected==building and g.selected.is_empty(),"inspected producer accepts mapped rally without changing inspection")
 check(g.camera_focus==camera_before,"producer map rally preserves camera")

 # A receipt is only shown for accepted commands.
 choose([]);g.minimap_order_time=0;map_click(Vector3(20,0,-16))
 check(g.minimap_order_time==0,"empty selection emits no acceptance ring")
 var wall:Dictionary=g.make_building("wall",Vector3(-8,0,-24),true)
 var wall_rally:Vector3=wall.rally
 choose([],wall);g.minimap_order_time=0;map_click(Vector3(20,0,-16))
 check(g.minimap_order_time==0 and wall.rally==wall_rally,"non-producing building keeps its rally and emits no acceptance ring")
 var convoy:Dictionary=g.make_unit("convoy",Vector3(-24,0,12))
 choose([convoy]);g.minimap_order_time=0;var convoy_goal:Vector3=convoy.goal
 map_click(Vector3(20,0,-16))
 check(g.minimap_order_time==0 and convoy.goal==convoy_goal,"convoy-only selection emits no order acceptance ring")
 choose([guard]);g.minimap_order_time=0;map_click(Vector3(20,0,-16),MOUSE_BUTTON_RIGHT,true)
 check(g.minimap_order_time==0,"fighter-only Shift click emits no worker-queue acceptance ring")
 choose([worker]);g.command_at(Vector3(20,0,-16));g.EscortOrders.assign(ally,worker,0)
 g.minimap_order_time=0;before=state(worker);map_click(ally.node.position)
 check(state(worker)==before,"rejected worker escort cycle preserves active order and emits no acceptance ring")
 ally.task="idle";ally.target=null

 # Blocks apply before either pan or command, even to direct GUI dispatch.
 choose([worker]);g.command_at(Vector3(-16,0,4))
 for flag in ["title_open","ended","active_card"]:
  g.set(flag,true);before=state(worker)
  map_click(Vector3(20,0,-16));map_click(Vector3(24,0,-24),MOUSE_BUTTON_LEFT)
  check(state(worker)==before,flag+" blocks minimap command and camera pan")
  g.set(flag,false)
 for property in ["options_panel","route_panel","dismantle_panel","choice_panel"]:
  var panel=PanelContainer.new();g.root_ui.add_child(panel);g.set(property,panel);before=state(worker)
  map_click(Vector3(20,0,-16));map_click(Vector3(24,0,-24),MOUSE_BUTTON_LEFT)
  check(state(worker)==before,property+" blocks minimap command and camera pan")
  g.set(property,null);panel.free()
 g.paused=true;map_click(Vector3(20,0,-16))
 check(worker.task=="move" and worker.goal.is_equal_approx(Vector3(18.35,0,-16)) and g.paused,"tactical pause still permits minimap commands without unpausing")
 g.paused=false;before=state(worker)
 map_click(Vector3(-20,0,16),MOUSE_BUTTON_RIGHT,false,false)
 map_click(Vector3(-20,0,16),MOUSE_BUTTON_LEFT,false,false)
 map_click(Vector3(-20,0,16),MOUSE_BUTTON_MIDDLE)
 g.minimap.gui_input.emit(InputEventMouseMotion.new())
 check(state(worker)==before,"button releases, middle click and mouse motion cannot issue map commands")

 # Actual viewport routing must consume map events before world selection.
 choose([guard]);g.camera_focus=Vector3(0,0,0);g.dragging=false
 await viewport_click(Vector3(20,0,-16),MOUSE_BUTTON_RIGHT)
 check(guard.task=="move" and guard.goal.is_equal_approx(Vector3(18.35,0,-16)),"viewport right map click reaches world command exactly at map location")
 check(g.camera_focus==Vector3.ZERO and g.selected==[guard] and not g.dragging,"viewport right map click never leaks into camera or world selection")
 var guard_goal:Vector3=guard.goal
 await viewport_click(Vector3(-24,0,24),MOUSE_BUTTON_LEFT)
 check(g.camera_focus==Vector3(-18,0,18) and g.selected==[guard] and guard.goal==guard_goal and not g.dragging,"viewport left map press/release pans without world selection or order leakage")
 g.paused=true;var elapsed:float=g.elapsed;g._process(1.0)
 check(g.minimap_order_time==0 and g.elapsed==elapsed and g.paused,"acceptance ring expires in display time without advancing a paused simulation")
 print("MINIMAP_COMMANDS_SUMMARY checks=%d failures=%d labels=%s"%[checks,failures.size(),failures])
 g.free();await process_frame;quit(0 if failures.is_empty() else 1)
