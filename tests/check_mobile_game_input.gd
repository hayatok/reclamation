extends SceneTree
var game
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func touch(point:Vector2,down:bool,index:int=0,canceled:bool=false):
 var e=InputEventScreenTouch.new();e.position=point;e.pressed=down;e.index=index;e.canceled=canceled;game._input(e)
func tap(point:Vector2):touch(point,true);touch(point,false)
func drag(point:Vector2,index:int=0):
 var e=InputEventScreenDrag.new();e.position=point;e.index=index;game._input(e)
func project(p:Vector3)->Vector2:return game.camera.unproject_position(p)
func run():
 var campaign=root.get_node("Campaign");campaign.launch=true;campaign.resume=false;campaign.current=0;campaign.muted=true;campaign.run_seed=37
 root.size=Vector2i(844,390)
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 game.camera_focus=Vector3(0,0,8);game.camera.position=game.camera_focus+Vector3(37,48,43);game.camera.look_at(game.camera_focus)
 await process_frame;await process_frame
 game.mobile_hud.sync();game.mobile_input.sync()
 check(game.mobile_enabled and game.mobile_hud.size==Vector2(844,390),"Native override uses CSS-equivalent 844x390")
 var worker=game.units.filter(func(u):return u.kind=="worker")[0]
 var at=project(worker.node.position+Vector3(0,.8,0))
 check(not game.mobile_hud.is_over_ui(at),"Starting worker is visible outside HUD")
 tap(at);check(worker in game.selected,"Tap selects one starting worker")
 var food=game.resource_nodes.filter(func(n):return n.resource=="food")[0]
 var food_point=project(food.node.position)
 check(not game.mobile_hud.is_over_ui(food_point),"Initial resource tap is outside HUD")
 tap(food_point);check(worker.task=="gather" and worker.target==food,"Second tap issues actual gather order")
 var original=worker.goal
 var area=Vector2(460,155)
 touch(area,true);drag(area+Vector2(35,0));touch(area+Vector2(35,0),false)
 check(worker.goal==original,"Camera drag release does not replace work order")
 var before_size=game.camera.size
 touch(Vector2(360,150),true,2);touch(Vector2(430,150),true,5);drag(Vector2(460,150),5);touch(Vector2(460,150),false,5);touch(Vector2(360,150),false,2)
 check(game.camera.size<before_size and worker.goal==original,"Pinch zoom does not issue an order")
 var selected=game.selected.duplicate()
 var ui_point=game.mobile_hud.range_button.get_global_rect().get_center()
 touch(ui_point,true);drag(area);touch(area,false)
 check(game.selected==selected and worker.goal==original,"UI-origin release cannot become world order")
 touch(area,true);game._mobile_reset("touchcancel");touch(area,false)
 check(worker.goal==original,"Web cancellation before ordinary release cannot command")
 game.touch_set_mode(1);touch(Vector2(300,120),true);drag(Vector2(500,200));game.touch_cancel();touch(Vector2(500,200),false)
 check(not game.dragging and game.mobile_input.controller.mode==0,"Cancel clears pending range selection")
 game.selected=[worker];game.inspected={};game.update_selection();game.set_build("house")
 var bank=game.resources
 game.touch_cancel();check(game.build_mode.is_empty() and game.resources==bank,"Touch cancel leaves placement uncharged")
 game.mobile_hud._show_selection();await process_frame
 check(game.mobile_input.modal(),"Expanded selection details block battlefield commands")
 var unchanged=worker.goal;tap(area);check(worker.goal==unchanged,"Touch outside details cannot issue orders")
 game.mobile_hud._close_popup();await process_frame
 var map_point=game.minimap.get_global_rect().get_center()
 var camera_before=game.camera_focus
 touch(map_point,true);drag(map_point+Vector2(20,0));touch(map_point+Vector2(20,0),false)
 check(game.camera_focus==camera_before,"Minimap drag release is not a completed map tap")
 game.touch_set_mode(2);tap(map_point)
 check(game.mobile_input.controller.mode==0 and worker.task=="move","Explicit minimap order uses existing command path once")
 var guards=game.units.filter(func(u):return u.kind=="guard")
 game.selected=[guards[0]];game.inspected={};game.update_selection()
 game.camera_focus=guards[1].node.position;game.mobile_input._camera();game.mobile_hud.sync()
 var ally_at=project(guards[1].node.position+Vector3(0,.8,0))
 tap(ally_at);check(game.selected==[guards[1]],"Context tap selects a friendly rather than issuing escort")
 game.selected=[guards[0]];game.update_selection();game.touch_set_mode(2);tap(ally_at)
 check(guards[0].task=="escort" and guards[0].target==guards[1],"Explicit touch order assigns persistent friendly escort")
 var hq=game.buildings[0];hq.hp-=1
 game.selected=[worker];game.inspected={};game.update_selection()
 game.camera_focus=hq.node.position;game.mobile_input._camera();game.mobile_hud.sync()
 game.touch_set_mode(2);tap(project(hq.node.position))
 check(worker.task=="repair" and worker.target==hq,"Explicit touch order repairs friendly building")
 game.select_workers();game.refresh_context_commands(true)
 check(game.context_actions.filter(func(a):return a.kind=="worker")[0].cost.is_empty(),"Build-page navigation does not claim worker recruitment cost")
 check(game.context_actions.filter(func(a):return a.kind=="house")[0].cost==game.GameRules.building("house").cost,"House retains real build cost")
 game.select_headquarters();game.refresh_context_commands(true)
 check(game.context_actions.filter(func(a):return a.kind=="worker")[0].cost==game.GameRules.unit("worker").cost,"HQ recruitment retains real worker cost")
 game.queue_free();await process_frame
 print("MOBILE_GAME_INPUT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
