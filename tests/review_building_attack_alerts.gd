extends SceneTree
## Real main-scene review fixture; scene setup supplies one outer shelter and
## three adjacent attackers. All subsequent damage, movement and orders are real.
## Default: live normal play. Optional --attack-review-stage=first|critical|lost
## fast-forwards and holds that exact scene for a native screenshot/click review.
var g:Node
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.run_seed=71221
 campaign.muted="--review-muted" in OS.get_cmdline_user_args()
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g
 var shelter:Dictionary=g.make_building("barracks",Vector3(-23,0,18),true)
 var workers:Array=g.units.filter(func(u):return u.kind=="worker")
 for worker in workers:g.economy.assign_resource(worker,g.resource_nodes[0])
 g.selected=workers;g.inspected={};g.update_selection()
 g.camera_focus=Vector3(14,0,16);g.camera.size=30
 g.center_notice.text="";g.notice_timer=0
 for i in 3:
  g.spawn_enemy(Vector3(-26.5,0,18+i*.06));g.enemies.back().cd=0
 var stage:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--attack-review-stage="):stage=arg.trim_prefix("--attack-review-stage=")
 if not stage.is_empty():
  g.set_process(false)
  for step in 400:
   g.advance_simulation_time(.05);g.update_building_attack_alert()
   if (stage=="first" and shelter.hp<shelter.maxhp) or (stage=="critical" and shelter.hp>0 and shelter.hp<=shelter.maxhp*.3) or (stage=="lost" and shelter.hp<=0):break
  if stage=="lost":g.advance_simulation_time(.05);g.update_building_attack_alert()
  g.paused=true;g.render_actors();g.update_ui();g.set_process(true)
 print("BUILDING_ATTACK_REVIEW ready stage=",stage if not stage.is_empty() else "live"," hp=",shelter.hp," camera=",g.camera_focus,". Click the alert; selected workers keep gathering. Space resumes a held review stage.")
