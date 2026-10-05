extends SceneTree
## Synthetic presentation regressions, not evidence of earned campaign progress.
const FX=preload("res://battle_fx.gd")
var passed:int=0
var failed:int=0
var fx:Node3D
var camera:Camera3D
var holder:Node3D

func _initialize()->void:
 call_deferred("run")

func check(ok:bool,label:String)->void:
 if ok:
  passed+=1
  print("PASS ",label)
 else:
  failed+=1
  push_error("FAIL "+label)

func building(kind:String="factory",position:Vector3=Vector3.ZERO)->Dictionary:
 var node:=Node3D.new()
 holder.add_child(node)
 node.position=position
 return {"node":node,"kind":kind,"built":1.0,"hp":1.0,"maxhp":280.0}

func check_cues(records:Array,count:int,label:String)->void:
 fx.update(0.0,camera,records)
 check(fx.critical_cue_count==count and fx.batches.flame.visible_instance_count==count and fx.batches.smoke.visible_instance_count==count*2,label)

func run()->void:
 root.size=Vector2i(1440,900)
 holder=Node3D.new()
 root.add_child(holder)
 camera=Camera3D.new()
 holder.add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=54.0
 camera.position=Vector3(37,48,43)
 camera.look_at(Vector3.ZERO)
 fx=FX.new()
 holder.add_child(fx)
 var record:Dictionary=building()
 check_cues([record],1,"a completed 1/280 HP factory has one fire and two wisps")
 record.hp=84.0
 check_cues([record],1,"exactly 30 percent HP remains critical")
 record.hp=84.01
 check_cues([record],0,"repair above 30 percent clears all damage quads in the same update")
 record.hp=0.0
 check_cues([record],0,"destroyed buildings do not retain fire")
 record.hp=-1.0
 check_cues([record],0,"negative HP does not retain fire")
 record.hp=1.0
 record.built=.999
 check_cues([record],0,"unfinished construction does not look like a burning completed building")
 record.built=1.0
 record.maxhp=0.0
 check_cues([record],0,"invalid maximum HP does not generate a cue")
 record.maxhp=280.0
 record.being_removed=true
 check_cues([record],0,"an in-progress removal clears the cue")
 record.erase("being_removed")
 record.node.hide()
 check_cues([record],0,"hidden buildings do not retain an independent visible cue")
 record.node.show()
 check_cues([record],1,"restoring a visible critical building restores its cue")
 check_cues([],0,"removal from the authoritative list clears fire without an expiry delay")
 check_cues([record],1,"loading a critical building reconstructs its presentation from existing fields")
 var before:Dictionary=record.duplicate(true)
 var original_transform:Transform3D=record.node.transform
 var original_rng:int=fx.rng.state
 fx.update(.25,camera,[record])
 check(record==before and record.node.transform==original_transform and fx.rng.state==original_rng,"damage animation never changes building state, transforms, or effect RNG")
 for frame:int in 12:fx.update(1.0/30.0,camera,[record])
 check(record==before and fx.critical_cue_count==1 and fx.batches.flame.visible_instance_count==1 and fx.batches.smoke.visible_instance_count==2,"paused simulation can keep rendering without accumulating cues or changing HP")
 # Headless dummy rendering returns identity from MultiMesh transform readback.
 # Actual billboard placement/shape is verified in the separate native review.
 var saved_visuals:Dictionary=fx._critical_particles([record],camera)
 fx._critical_particles([],camera)
 check(fx._critical_particles([record],camera)==saved_visuals,"same position and visual clock reconstruct identical cues without stored particle state")
 for kind:String in FX.CRITICAL_ANCHORS:
  record.kind=kind
  check_cues([record],1,"known structure %s has an authored surface anchor"%kind)
 record.kind="factory"
 var anchor:Vector3=FX.CRITICAL_ANCHORS.factory
 check(anchor.distance_to(Vector3(-.82,4.02,.66))>1.5 and absf(anchor.y-2.80037)<.04,"factory cue starts on its verified roof, away from the working chimney")
 var offscreen:Dictionary=building("factory",Vector3(500,0,500))
 var many:Array=[offscreen]
 for i:int in 24:
  many.append(building("factory",Vector3(float(i%6)*2-5,0,float(i/6)*2-3)))
 check_cues(many,FX.CRITICAL_BUILDING_LIMIT,"offscreen damage cannot consume the fixed 16-building visible quota")
 var sources:Array=fx._critical_sources(many,camera)
 var ordered:bool=true
 for i:int in range(1,sources.size()):
  ordered=ordered and float(sources[i-1].distance)<=float(sources[i].distance)
 check(ordered and sources[0].pos.x<100,"overflow keeps nearest visible buildings in deterministic order")
 for i:int in 300:
  fx.spawn("flame",Vector3.ZERO,10.0,1.0,Color.WHITE)
  fx.spawn("smoke",Vector3.ZERO,10.0,1.0,Color.WHITE)
 fx.update(0.0,camera,many)
 check(fx.particles.flame.size()==240 and fx.particles.smoke.size()==96,"combat particles cannot consume reserved damage capacity")
 check(fx.batches.flame.visible_instance_count==256 and fx.batches.smoke.visible_instance_count==128 and fx.critical_cue_count==16,"all 48 essential quads survive saturated combat batches")
 var batch_count:int=fx.batches.size()
 var allocated:int=0
 for batch:MultiMesh in fx.batches.values():allocated+=batch.instance_count
 check(batch_count==7 and allocated==7*FX.LIMIT and fx.lights.size()==2,"damage adds no batches, allocated instances, or lights")
 for i:int in 6:
  fx.blast(Vector3(i*3,0,0),3.0,true,true)
 fx.update(.01,camera,many)
 check(fx.critical_cue_count==16 and fx.batches.flame.visible_instance_count==256 and fx.batches.smoke.visible_instance_count==128,"reduced-effects blasts and blast-budget exhaustion cannot suppress essential cues")
 for list:Array in fx.particles.values():list.clear()
 fx.hide()
 check_cues([record],0,"aftermath hiding leaves no repopulated persistent damage quads")
 fx.show()
 record.node.queue_free()
 check_cues([record],0,"queued deletion clears damage before the node is freed")
 await process_frame
 check_cues([record],0,"freed node references are safely ignored")
 holder.free()
 print("CRITICAL_BUILDING_DAMAGE_SUMMARY passed=%d failed=%d"%[passed,failed])
 quit(1 if failed else 0)
