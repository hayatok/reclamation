extends SceneTree
## Exact earned-state visual A/B and frozen-scene cost. Not live-game FPS.
var game:Node
var output:String="user://critical_damage_review"
var baseline_state:Dictionary
func _initialize():call_deferred("run")
func freeze(node:Node)->void:
 node.process_mode=Node.PROCESS_MODE_DISABLED
 for child in node.get_children():freeze(child)
func settle()->void:
 for i in 3:
  await process_frame
  await RenderingServer.frame_post_draw
func summary(values:Array)->Dictionary:
 var sorted=values.duplicate();sorted.sort()
 var total:float=0
 for value in values:total+=float(value)
 return {"n":values.size(),"mean":total/values.size(),"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))]}
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--damage-output="):output=arg.trim_prefix("--damage-output=")
 DirAccess.make_dir_recursive_absolute(output)
 var campaign=root.get_node("Campaign")
 campaign.current=1;campaign.launch=true;campaign.resume=true;campaign.muted=true;campaign.performance_mode=false
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 if not is_equal_approx(game.elapsed,518.85):
  push_error("Expected earned Mission2 age3-start fixture");quit(2);return
 var factory:Dictionary={}
 for building in game.buildings:
  if building.kind=="factory":factory=building
 assert(not factory.is_empty() and factory.hp==1 and factory.maxhp==280)
 game.paused=true
 await settle()
 freeze(game)
 for tween in get_processed_tweens():tween.pause()
 game.render_actors()
 game.battle_visibility.update_visibility(game.camera,game.units,game.enemies,game.shells,1.5)
 game.update_ui();game.hud_depth_mask.sync_now()
 game.battle_fx.visual_clock=2.0
 baseline_state=game.checkpoint_data()
 var images=[]
 for enabled in [false,true]:
  game.battle_fx.update(0,game.camera,game.buildings if enabled else [])
  await settle()
  var filename="critical_after.png" if enabled else "critical_before.png"
  assert(root.get_texture().get_image().save_png(output.path_join(filename))==OK)
  images.append({"name":filename,"critical_cues":game.battle_fx.critical_cue_count,"factory_hp":factory.hp,"camera_size":game.camera.size,"state_equal":baseline_state==game.checkpoint_data()})
 var blocks=[]
 var pooled={"before":{"frame_ms":[],"fx_submit_ms":[],"draws":[],"primitives":[]},"after":{"frame_ms":[],"fx_submit_ms":[],"draws":[],"primitives":[]}}
 for block in 4:
  var enabled=block in [1,2]
  var label="after" if enabled else "before"
  var samples={"frame_ms":[],"fx_submit_ms":[],"draws":[],"primitives":[]}
  var last=Time.get_ticks_usec()
  for frame in 60:
   await process_frame
   var start=Time.get_ticks_usec()
   game.battle_fx.update(0,game.camera,game.buildings if enabled else [])
   var submit=float(Time.get_ticks_usec()-start)/1000
   await RenderingServer.frame_post_draw
   var now=Time.get_ticks_usec()
   var wall=float(now-last)/1000;last=now
   if frame<10:continue
   var row={"frame_ms":wall,"fx_submit_ms":submit,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
   for key in row:
    samples[key].append(row[key]);pooled[label][key].append(row[key])
  var stats={}
  for key in samples:stats[key]=summary(samples[key])
  blocks.append({"block":block,"variant":label,"summary":stats,"samples":samples})
  print("CRITICAL_COST_BLOCK ",block," ",label," ",JSON.stringify(stats))
 var stats={}
 for label in pooled:
  stats[label]={}
  for key in pooled[label]:stats[label][key]=summary(pooled[label][key])
 var result={"scope":"frozen earned scene, paired ABBA, not live-game FPS","renderer":RenderingServer.get_video_adapter_name(),"elapsed":game.elapsed,"units":game.units.size(),"enemies":game.enemies.size(),"camera_size":game.camera.size,"state_equal":baseline_state==game.checkpoint_data(),"images":images,"blocks":blocks,"summary":stats}
 var file=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
 print("CRITICAL_REVIEW_COMPLETE ",JSON.stringify(stats))
 quit(0 if result.state_equal else 1)
