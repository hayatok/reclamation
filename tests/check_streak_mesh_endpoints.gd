extends SceneTree
## Independent BoxMesh endpoint regression. Also runs against unmodified v033.
## Native runs additionally read the submitted MultiMesh transforms.
const FX=preload("res://battle_fx.gd")
var checks:int=0
var failures:int=0
var worst_error:float=0
func _initialize():call_deferred("run")
func near(actual:Vector3,expected:Vector3,message:String):
 checks+=1
 var error:float=actual.distance_to(expected)
 worst_error=maxf(worst_error,error)
 if error>.0001:failures+=1;push_error(message+" error="+str(error))
func endpoints(transform:Transform3D,a:Vector3,b:Vector3,label:String):
 # These are the front/back face centres of the actual unit BoxMesh, not a
 # reimplementation of the effect's direction/length calculation.
 near(transform*Vector3(0,0,.5),a,label+" shooter face")
 near(transform*Vector3(0,0,-.5),b,label+" target face")
func run():
 var fx=FX.new();root.add_child(fx)
 var camera=Camera3D.new();root.add_child(camera)
 camera.position=Vector3(20,20,20);camera.look_at(Vector3.ZERO)
 var cases:Array=[]
 for heading:int in 8:
  for rise:float in [-2.5,0.0,4.0]:
   var a:=Vector3(3.7,1.2,-4.1)
   var b:Vector3=a+Vector3(sin(heading*TAU/8)*7,rise,-cos(heading*TAU/8)*7)
   cases.append([a,b])
 # Near vertical uses the alternate up axis; a short segment exercises width/length.
 cases.append([Vector3(1,2,3),Vector3(1.001,10,3)])
 cases.append([Vector3(-2,1,4),Vector3(-2.2,1.3,4.1)])
 for pair:Array in cases:fx.streak(pair[0],pair[1],Color.WHITE,.2,.035)
 fx.update(0,camera)
 for index:int in cases.size():
  var item:Dictionary=fx.particles.streak[index]
  var transform:=Transform3D(item.basis,item.pos)
  endpoints(transform,cases[index][0],cases[index][1],"CPU BoxMesh "+str(index))
  if DisplayServer.get_name()!="headless":
   var submitted:Transform3D=fx.batches.streak.get_instance_transform(index)
   endpoints(submitted,cases[index][0],cases[index][1],"submitted MultiMesh "+str(index))
 print("STREAK_MESH_ENDPOINTS checks=",checks," failures=",failures," worst_error=",worst_error," gpu_readback=",DisplayServer.get_name()!="headless")
 fx.free();camera.free();quit(1 if failures else 0)
