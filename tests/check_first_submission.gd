extends SceneTree
const Before=preload("res://tests/fixtures/battle_fx_v034.gd")
const After=preload("res://battle_fx.gd")
var checks:int=0
var failures:int=0
var camera:Camera3D
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func instance(script)->Node3D:
 var fx=script.new();root.add_child(fx);return fx
func rifle(fx):
 fx.muzzle(Vector3.ZERO)
 fx.beam(Vector3.ZERO,Vector3(4,1,-6),Color("d2a148"),.1,.055)
func state(fx)->Dictionary:
 var result={"rng":str(fx.rng.state),"lights":[],"particles":{}}
 for light in fx.lights:result.lights.append([light.life,light.node.light_energy])
 for kind in fx.particles:
  result.particles[kind]={"submitted":fx.batches[kind].visible_instance_count,"live":fx.particles[kind].duplicate(true)}
 return result
func run():
 camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(12,15,20);camera.look_at(Vector3.ZERO)
 var baseline=instance(Before);var candidate=instance(After)
 for tick in 50:
  if tick in [0,2,10,18,35]:rifle(baseline);rifle(candidate)
  if tick==5:baseline.blast(Vector3(8,0,-5),3,true);candidate.blast(Vector3(8,0,-5),3,true)
  baseline.update(1.0/60,camera);candidate.update(1.0/60,camera)
  check(state(baseline)==state(candidate),"60fps lifetime/visual state/RNG must match on tick "+str(tick))
 baseline.free();candidate.free()
 for dt:float in [1.0/60,1.0/30,.08,.12,.2]:
  var fx=instance(After);rifle(fx);fx.update(dt,camera)
  check(fx.batches.flash.visible_instance_count==1,"fresh flash is submitted at "+str(dt))
  check(fx.batches.streak.visible_instance_count==2,"both fresh tracer layers are submitted at "+str(dt))
  check(fx.batches.smoke.visible_instance_count==1,"ordinary smoke survives unchanged")
  if dt>=.12:check(fx.particles.flash.is_empty() and fx.particles.streak.is_empty(),"expired first samples are not retained in pools")
  fx.update(.4,camera)
  check(fx.batches.flash.visible_instance_count==0 and fx.batches.streak.visible_instance_count==0,"older effects do not reappear")
  fx.free()
 var mixed=instance(After);rifle(mixed);mixed.update(1.0/60,camera);rifle(mixed);mixed.update(.2,camera)
 check(mixed.batches.flash.visible_instance_count==1 and mixed.batches.streak.visible_instance_count==2,"only the new event gets a first sample")
 mixed.update(0,camera)
 check(mixed.batches.flash.visible_instance_count==0 and mixed.batches.streak.visible_instance_count==0,"zero-delta update does not replay expired samples")
 mixed.free()
 var paused=instance(After);rifle(paused);paused.update(0,camera);paused.update(.2,camera)
 check(paused.batches.flash.visible_instance_count==0 and paused.batches.streak.visible_instance_count==0,"a zero-delta submission counts as the first presentation")
 paused.free()
 var pooled=instance(After)
 for i in 300:rifle(pooled)
 check(pooled.particles.flash.size()==256 and pooled.particles.streak.size()==256 and pooled.particles.smoke.size()==96,"accepted events respect original caps")
 pooled.update(.2,camera)
 check(pooled.batches.flash.visible_instance_count==256 and pooled.batches.streak.visible_instance_count==256,"first samples never exceed original caps")
 check(pooled.particles.flash.is_empty() and pooled.particles.streak.is_empty(),"all expired burst samples leave their pools immediately")
 pooled.update(0,camera)
 check(pooled.batches.flash.visible_instance_count==0 and pooled.batches.streak.visible_instance_count==0,"no overflow queue is replayed")
 pooled.free()
 for dt:float in [.12,.2]:
  var fx=instance(After);fx.blast(Vector3.ZERO,3,true);fx.update(dt,camera)
  var alive=0
  for light in fx.lights:
   if light.node.light_energy>0:alive+=1
   check(light.life==0,"light real lifetime still expires")
  check(alive==1,"accepted heavy-blast light has one visible submission")
  fx.update(0,camera)
  check(fx.lights.all(func(light):return light.node.light_energy==0),"expired light does not remain lit when paused")
  fx.free()
 for emitter in ["trail","chain"]:
  var fx=instance(After)
  if emitter=="trail":fx.trail(Vector3.ZERO,Vector3(4,1,-6),true)
  else:fx.beam(Vector3.ZERO,Vector3(4,1,-6),Color("91c3df"),.2,.055)
  var accepted=fx.particles.streak.size();fx.update(.2,camera)
  check(fx.batches.streak.visible_instance_count==accepted and fx.particles.streak.is_empty(),emitter+" is presented once and discarded")
  fx.free()
 camera.free();print("FIRST_SUBMISSION checks=",checks," failures=",failures);quit(1 if failures else 0)
