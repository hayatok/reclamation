extends Node
## Standard RTS scenery occlusion: only art opacity changes. No simulation edits.
var district:Node3D
var elapsed:float=0
var refresh:float=0
var hold_until:Array=[]
var opacity:Array=[]
func update_visibility(camera:Camera3D,units:Array,enemies:Array,shells:Array,delta:float):
 if not is_instance_valid(district) or "--no-occlusion" in OS.get_cmdline_user_args():return
 var structures=district.get("occlusion_buildings")
 if not structures is Array or structures.is_empty():return
 elapsed+=delta;refresh-=delta
 while opacity.size()<structures.size():opacity.append(1.0);hold_until.append(0.0)
 if refresh<=0:
  refresh=.10
  var points:Array[Vector3]=[]
  for collection in [units,enemies]:
   for actor in collection:
    if actor.get("dead",false) or not is_instance_valid(actor.node):continue
    points.append(actor.node.global_position+Vector3(0,.9*actor.node.scale.y,0))
  for shell in shells:
   if is_instance_valid(shell.node):points.append(shell.node.global_position)
   points.append(shell.to+Vector3(0,.4,0))
  var viewport=camera.get_viewport().get_visible_rect()
  var visible_area=Rect2(Vector2(0,60),Vector2(viewport.size.x,maxf(100,viewport.size.y-270)))
  var rays=[]
  for point in points:
   if camera.is_position_behind(point):continue
   var screen=camera.unproject_position(point)
   if visible_area.has_point(screen):rays.append([camera.project_ray_origin(screen),point])
  for i in structures.size():
   var bounds:AABB=structures[i].bounds
   bounds=bounds.grow(.15)
   for ray in rays:
    if bounds.intersects_segment(ray[0],ray[1])!=null:
     hold_until[i]=elapsed+1.2
     break
 for i in structures.size():
  var desired=.10 if hold_until[i]>elapsed else 1.0
  var next=move_toward(float(opacity[i]),desired,delta*4)
  if not is_equal_approx(next,opacity[i]):
   opacity[i]=next
   district.set_building_fade(i,next)
