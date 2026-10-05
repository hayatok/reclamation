extends SceneTree
const Alerts=preload("res://building_attack_alerts.gd")
var g:Node
var checks:=0
var failures:Array[String]=[]
class SilentAlerts extends RefCounted:
 var current:Dictionary={}
 func record_hit(_target:Dictionary,_now:float):pass
 func update(_now:float,_buildings:Array)->bool:return false
 func reset():pass
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)
func scene():
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true;campaign.run_seed=71221
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
func attackers(p:Vector3,count:int):
 for i in count:
  g.spawn_enemy(p+Vector3(0,0,i*.04));g.enemies.back().cd=0
func tick(count:int=1):
 for i in count:g.advance_simulation_time(.05);g.update_building_attack_alert()
func click_alert():
 await process_frame
 var point:Vector2=g.building_attack_button.get_global_rect().get_center()
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.global_position=point
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
 await process_frame
func run():
 scene();await process_frame
 var workers:Array=g.units.filter(func(u):return u.kind=="worker")
 for worker in workers:g.economy.assign_resource(worker,g.resource_nodes[0])
 g.selected=workers;g.inspected={};g.update_selection()
 var barracks:Dictionary=g.make_building("barracks",Vector3(-23,0,18),true)
 var position:Vector3=barracks.node.position
 g.camera_focus=Vector3(16,0,16);g.camera.size=30
 attackers(position+Vector3(-3.5,0,0),6)
 var camera_before:Vector3=g.camera_focus
 g.audio_system.set_muted(false)
 tick()
 check(g.audio_system.last_play.has("warning") and g.audio_system.rotations.get("warning",0)==1 and int(g.audio_system.EVENTS.warning[5])==3,"first hit uses the existing protected tactical warning pool")
 check(barracks.hp==286,"six real ordinary swipes retain exact 9-point damage")
 check(g.building_attack_button.visible and g.building_attack_button.text=="訓練所：攻撃を受けた","offscreen training shelter produces one named temporary alert")
 check(g.building_attack_alerts.current.position==position,"minimap cue and alert share the attacked building's real location")
 check(g.camera_focus==camera_before and not g.paused and g.selected==workers and workers.all(func(w):return w.task=="gather"),"new attack never pans, pauses, selects, or interrupts gathering")
 var rng_before:Array=[g.rng.state,g.card_rng.state,g.visual_rng.state]
 for i in 10:g.update_building_attack_alert()
 check([g.rng.state,g.card_rng.state,g.visual_rng.state]==rng_before,"presentation updates consume none of the three run random streams")
 var first_show:float=g.building_attack_alerts.last_shown
 var first_sound:float=g.building_attack_alerts.last_sound
 tick(10)
 check(g.building_attack_alerts.last_shown==first_show and g.building_attack_alerts.last_sound==first_sound,"repeated swarm hits do not restart the toast or warning sound")
 await click_alert()
 check(g.camera_focus==Vector3(-18,0,18) and g.selected==workers and workers.all(func(w):return w.task=="gather"),"actual HUD mouse click focuses clamped location without changing selection or orders")
 g.camera_focus=camera_before;await click_alert()
 check(g.camera_focus==Vector3(-18,0,18),"repeated alert clicks remain usable")
 g.paused=true;g.camera_focus=camera_before;await click_alert()
 check(g.camera_focus==Vector3(-18,0,18) and g.paused,"player-chosen tactical pause retains actionable alert without unpausing")
 g.paused=false;g.show_options();g.update_building_attack_alert();g.camera_focus=camera_before
 g.focus_building_attack()
 check(g.building_attack_button.disabled and g.camera_focus==camera_before,"options overlay blocks alert focus")
 g.close_options();await process_frame;g.update_building_attack_alert()
 check(not g.building_attack_button.disabled and not g.paused,"closing options restores actionable alert and prior running state")
 for i in 100:
  tick()
  if barracks.hp<=barracks.maxhp*.3:break
 check(barracks.hp>0 and g.building_attack_button.text.begins_with("訓練所：耐久危険"),"real continued damage upgrades the same alert at 30 percent health")
 check(g.audio_system.rotations.get("warning",0)==1,"critical swarm deterioration does not replay the protected sound within eight seconds")
 check(g.building_attack_alerts.last_sound==first_sound,"critical deterioration inside eight seconds does not repeat audio")
 for i in 100:
  tick()
  if barracks.hp<=0:break
 tick();await process_frame
 check(barracks not in g.buildings and not is_instance_valid(barracks.node),"ordinary simulation removes the destroyed shelter")
 check(g.building_attack_button.text=="訓練所：喪失" and g.building_attack_alerts.current.severity==3,"destroyed target immediately reads lost instead of alive or repairable")
 g.camera_focus=camera_before;await click_alert()
 check(g.camera_focus==Vector3(-18,0,18),"loss alert safely focuses the stored location after its node is freed")
 tick(125)
 check(not g.building_attack_button.visible and g.building_attack_alerts.current.is_empty(),"loss alert and corresponding map marker expire after six simulation seconds")
 g.free();await process_frame

 scene();await process_frame
 var wall:Dictionary=g.make_building("wall",Vector3(-23,0,18),true)
 var tower:Dictionary=g.make_building("tower",Vector3(23,0,18),true)
 attackers(wall.node.position+Vector3(-2,0,0),3)
 attackers(tower.node.position+Vector3(2,0,0),3)
 tick(20)
 check(wall.hp<wall.maxhp and tower.hp<tower.maxhp and g.building_attack_alerts.recent.is_empty(),"real wall and tower engagements do not flood strategic alerts")
 g.free();await process_frame

 scene();await process_frame
 var hq:Dictionary=g.buildings[0]
 var depot:Dictionary=g.make_building("depot",Vector3(-23,0,18),true)
 var hq_hp:float=hq.hp
 # Existing boss AoE is the second actual damage path.
 var boss:Dictionary={"attack_pos":hq.node.position,"cd":0.0}
 g.boss_impact(boss)
 attackers(depot.node.position+Vector3(-2.9,0,0),1)
 tick()
 check(hq.hp==hq_hp-120 and g.building_attack_alerts.current.target==hq,"boss AoE preserves exact damage and simultaneous HQ danger has priority")
 var first_global:float=g.building_attack_alerts.last_shown
 tick(30)
 check(g.building_attack_alerts.current.target==hq and g.building_attack_alerts.last_shown==first_global,"other building hits cannot replace the alert inside the three-second global gap")
 tick(35)
 check(g.building_attack_alerts.current.target==depot,"still-current economic engagement appears after the global gap")
 var old_target_id:int=depot.node.get_instance_id()
 var data:Dictionary=g.checkpoint_data()
 check(not data.has("building_attack_alerts") and int(data.version)==3,"attack UI does not add fields or change save schema")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"actual atomic checkpoint still round-trips")
 check(g.building_attack_alerts.current.is_empty() and g.building_attack_alerts.recent.is_empty() and not g.building_attack_button.visible,"checkpoint restore discards all transient alert identities")
 check(g.buildings.back().node.get_instance_id()!=old_target_id,"restore test created new building identities")
 g.free();await process_frame

 # Combat/economy/order/checkpoint equivalence with only this observer disabled.
 var results:Array=[]
 for enabled in [true,false]:
  scene()
  if not enabled:g.building_attack_alerts=SilentAlerts.new()
  var building:Dictionary=g.make_building("barracks",Vector3(-23,0,18),true)
  for worker in g.units.filter(func(u):return u.kind=="worker"):g.economy.assign_resource(worker,g.resource_nodes[0])
  attackers(building.node.position+Vector3(-3.5,0,0),6)
  tick(500)
  results.append(JSON.stringify(g.checkpoint_data()))
  g.free();await process_frame
 check(results[0]==results[1],"25-second real simulation has identical combat, economy, orders, RNG, and checkpoint with observer enabled or disabled")
 print("BUILDING_ATTACK_ALERTS_SUMMARY checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
