extends SceneTree
## Run headless for transforms/FX or natively to additionally read back GPU batch poses.
const ActorVisuals=preload("res://actor_visuals.gd")
const WeaponMuzzles=preload("res://weapon_muzzles.gd")
const Interpolation=preload("res://render_interpolation.gd")
const Horde=preload("res://horde_renderer.gd")
const FX=preload("res://battle_fx.gd")
var checks:int=0
var failures:int=0

func _initialize():call_deferred("run")
func check(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func near(a:Vector3,b:Vector3,message:String):check(a.distance_to(b)<.0001,message+" error="+str(a.distance_to(b)))

func run():
 var scene=Node3D.new();root.add_child(scene)
 # Nonidentity world and renderer transforms catch world/local double transforms.
 scene.transform=Transform3D(Basis(Vector3.UP,.31),Vector3(3,0,-7))
 var renderer=Horde.new();scene.add_child(renderer)
 renderer.transform=Transform3D(Basis(Vector3.UP,-.22),Vector3(-2,0,1))
 var fx=FX.new();root.add_child(fx)
 var camera=Camera3D.new();root.add_child(camera)
 camera.position=Vector3(22,35,29);camera.look_at(Vector3.ZERO)
 var interpolation=Interpolation.new()
 var units:Array=[]
 for kind:String in ["guard","grenade","siegecart"]:
  for direction:int in 8:
   var node=Node3D.new();scene.add_child(node)
   node.position=Vector3(direction*3,0,units.size()/8*6)
   node.rotation.y=direction*TAU/8
   if kind!="siegecart":ActorVisuals.add_human(node,kind)
   else:interpolation.visual_root(node)
   units.append({"node":node,"kind":kind,"hp":100.0})
 for kind:String in ["guard","grenade"]:
  var tip:Vector3=ActorVisuals.muzzle_local(kind)
  var bounds:AABB=ActorVisuals.mesh_for(kind,"armR").get_aabb()
  check(absf(bounds.position.z-tip.z)<.00001,kind+" socket is on barrel front face")
 interpolation.reset(units,[],[])
 for moving:bool in [false,true]:
  for attack_age:float in [0.0,.045,.19,.38]:
   interpolation.before_step(units,[],[])
   for unit:Dictionary in units:
    unit.node.position+=Vector3(.09,0,-.08) if moving else Vector3.ZERO
    unit.node.rotation.y+=.18
    if unit.kind!="siegecart":ActorVisuals.pose(unit.node,1.3,moving,attack_age,.45 if attack_age>.2 else -1)
   interpolation.after_step(units,[],[])
   for alpha:float in [0.0,.25,.7,1.0]:
    var rendered:Dictionary=interpolation.frame(alpha)
    renderer.update_friends(units,rendered)
    for index:int in units.size():
     var unit:Dictionary=units[index]
     var state:Dictionary=rendered[unit.node.get_instance_id()]
     var socket:Dictionary=WeaponMuzzles.anchor(unit)
     var actual:Vector3=WeaponMuzzles.world_position(socket,rendered,Vector3.INF)
     if unit.kind=="siegecart":
      near(actual,interpolation.visual_root(unit.node).global_transform*WeaponMuzzles.SIEGE_MUZZLE,"cart visual root socket")
     else:
      var expected:Vector3=state.world*state.parts[5]*ActorVisuals.muzzle_local(unit.kind)
      near(actual,expected,"human interpolated root/arm socket")
      if DisplayServer.get_name()!="headless":
       var gpu:Transform3D=renderer._friendly_batches[unit.kind][5].get_instance_transform(index%8)
       near(actual,renderer.global_transform*gpu*ActorVisuals.muzzle_local(unit.kind),"socket on submitted ArmR mesh")
     fx.muzzle(Vector3.ZERO,unit.kind=="siegecart",socket)
     if unit.kind=="guard":fx.beam(Vector3.ZERO,actual-state.world.basis.z*8+Vector3(0,.3,0),Color("d2a148"),.1,.055,socket)
    fx.update(0,camera,[],rendered)
    for item:Dictionary in fx.particles.flash:
     near(item.pos,WeaponMuzzles.world_position(item.muzzle,rendered,Vector3.INF),"flash on current barrel")
    for item:Dictionary in fx.particles.streak:
     # A streak's +Z end is the shooter because Basis.looking_at faces -Z.
     var start:Vector3=Transform3D(item.basis,item.pos)*Vector3(0,0,.5)
     near(start,WeaponMuzzles.world_position(item.muzzle,rendered,Vector3.INF),"tracer begins at current barrel")
     near(Transform3D(item.basis,item.pos)*Vector3(0,0,-.5),item.endpoint,"tracer ends at target")
    for item:Dictionary in fx.particles.smoke:check(not item.has("muzzle"),"smoke detaches after first display")
    for list:Array in fx.particles.values():list.clear()
 var rendered:Dictionary=interpolation.frame(.5)
 var unit:Dictionary=units[0]
 var socket:Dictionary=WeaponMuzzles.anchor(unit)
 fx.muzzle(Vector3.ZERO,false,socket)
 fx.beam(Vector3.ZERO,Vector3(0,3,-20),Color("d2a148"),.1,.055,socket)
 fx.update(0,camera,[],rendered)
 var smoke:Vector3=fx.particles.smoke[0].pos
 unit.node.position+=Vector3(5,0,0)
 interpolation.snap_actor(unit.node)
 rendered=interpolation.frame(1)
 fx.update(0,camera,[],rendered)
 near(fx.particles.smoke[0].pos,smoke,"smoke does not follow shooter after launch")
 near(fx.particles.flash[0].pos,WeaponMuzzles.world_position(socket,rendered,Vector3.INF),"flash follows shooter while active")
 check(fx.get_child_count()==9,"no new effect batches or lights")
 check(renderer._friendly_batches.guard[0].visible_instance_count==8,"guard batching capacity unchanged")
 for list:Array in fx.particles.values():list.clear()
 var building=Node3D.new();scene.add_child(building)
 building.position=Vector3(-9,0,4);building.rotation.y=.7
 for shot:int in 2:
  fx.muzzle(Vector3.ZERO,false,WeaponMuzzles.anchor({"node":building,"kind":"tower","shots":shot}))
 fx.update(0,camera)
 for shot:int in 2:
  near(fx.particles.flash[shot].pos,building.to_global(Vector3(-.22 if shot==0 else .22,3.30,-1.23)),"two tower barrels remain independent in one render frame")
 near(WeaponMuzzles.world_position(WeaponMuzzles.anchor({"node":building,"kind":"mortar"}),{},Vector3.INF),building.to_global(Vector3(0,2.21,-2.40)),"fixed mortar front-cap socket")
 print("MUZZLE_TRANSFORMS_SUMMARY checks=",checks," failures=",failures," gpu_readback=",DisplayServer.get_name()!="headless")
 scene.free();fx.free();camera.free()
 quit(1 if failures else 0)
