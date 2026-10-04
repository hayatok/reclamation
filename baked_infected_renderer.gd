extends Node3D
## Original Blender rig baked into shared pose meshes. Simulation roots stay untouched.
const Library = preload("res://infected_pose_library.gd")
var batches: Dictionary = {}
var buffers: Dictionary = {}
var capacities: Dictionary = {}
var members: Dictionary = {}
var last_positions: Dictionary = {}
var active: bool = false
var visible_count: int = 0
var near_count: int = 0
var far_count: int = 0
var near_lod: bool = false
var force_far: bool = false

func _ready() -> void:
 Library.configure("res://assets/models/infected_baked_poses.glb", "res://assets/models/infected_baked_poses_far.glb")
 for distant in [false,true]:
  for clip in Library.COUNTS:
   for frame in Library.COUNTS[clip]:
    var key: String = "%s_%02d_%s" % [clip,frame,str(distant)]
    var mm := MultiMesh.new()
    mm.transform_format=MultiMesh.TRANSFORM_3D
    mm.use_colors=true
    mm.mesh=Library.mesh_for(clip,frame,distant)
    if mm.mesh==null:push_error("Missing infected pose "+key);return
    # Meshes share their original opaque atlas material. Per-instance color variation.
    var material=mm.mesh.surface_get_material(0)
    if material is StandardMaterial3D:material.vertex_color_use_as_albedo=true
    var node:=MultiMeshInstance3D.new()
    node.multimesh=mm
    node.name="Infected_"+key
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if distant else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(node)
    batches[key]=mm;buffers[key]=PackedFloat32Array();capacities[key]=0;members[key]=[]
 active=true

func update_crowd(enemies:Array,elapsed:float,camera:Camera3D)->void:
 if not active:return
 visible_count=0;near_count=0;far_count=0
 for key in members:members[key].clear()
 var rect:=get_viewport().get_visible_rect().grow(90)
 # Hysteresis avoids switching mesh density repeatedly during camera zoom.
 if camera!=null:
  var projected_height:float=get_viewport().get_visible_rect().size.y*1.7/maxf(camera.size,1)
  if projected_height>39:near_lod=true
  elif projected_height<32:near_lod=false
 var surviving:Dictionary={}
 for e in enemies:
  if e.get("dead",false) or e.get("armored",false) or float(e.get("speed",1.65))>2.0:continue
  var actor:Node3D=e.get("node")
  if not is_instance_valid(actor) or actor.is_queued_for_deletion():continue
  var id:int=actor.get_instance_id()
  var position:Vector3=actor.global_position
  var moving:bool=position.distance_squared_to(last_positions.get(id,position+Vector3.ONE))>.000001
  surviving[id]=position
  if camera!=null and (camera.is_position_behind(position) or not rect.has_point(camera.unproject_position(position+Vector3.UP*.8))):continue
  var clip:String="walk" if moving else "idle"
  var age:float=elapsed
  var phase:float=float(id%127)/127.0
  var corpse:bool=e.has("life")
  if corpse:clip="death";age=3.5-float(e.life);phase=0
  elif elapsed-float(e.get("attack_at",-100.0))<.8:clip="attack";age=elapsed-float(e.attack_at);phase=0
  var frame:int=Library.frame_index(clip,age,phase)
  var far_lod:bool=force_far or not near_lod
  var key:String="%s_%02d_%s"%[clip,frame,str(far_lod)]
  # Corpse animation is already baked. Ignore the legacy procedural topple root.
  var world:Transform3D=actor.global_transform
  if corpse:
   world=actor.get_parent().global_transform*e.start
   if e.life<1:world.basis=world.basis.scaled(Vector3.ONE*maxf(.03,e.life))
  var stature:float=.94+float(id%7)*.02
  world.basis=world.basis.scaled(Vector3(stature,stature,stature))
  var hit_response:float=clampf((float(e.get("hit_until",0))-elapsed)/.12,0,1)
  world.origin+=world.basis.z*hit_response*.07
  members[key].append([global_transform.affine_inverse()*world,id])
  visible_count+=1
  if far_lod:far_count+=1
  else:near_count+=1
 last_positions=surviving
 for key in batches:
  var mm:MultiMesh=batches[key]
  var count:int=members[key].size()
  if count==0:mm.visible_instance_count=0;continue
  if count>capacities[key]:
   capacities[key]=maxi(8,int(pow(2,ceil(log(float(count))/log(2.0)))))
   mm.instance_count=capacities[key]
   buffers[key].resize(capacities[key]*16)
  var buffer:PackedFloat32Array=buffers[key]
  var low:=Vector3(INF,INF,INF);var high:=-low
  for i in count:
   var transform:Transform3D=members[key][i][0]
   _write(buffer,i*16,transform)
   var tone:float=.91+float(int(members[key][i][1])%5)*.0225
   buffer[i*16+12]=tone;buffer[i*16+13]=tone;buffer[i*16+14]=tone;buffer[i*16+15]=1
   low=low.min(transform.origin-Vector3.ONE*2.5);high=high.max(transform.origin+Vector3.ONE*2.5)
  buffers[key]=buffer
  mm.buffer=buffer;mm.custom_aabb=AABB(low,high-low);mm.visible_instance_count=count

static func _write(buffer:PackedFloat32Array,o:int,t:Transform3D)->void:
 buffer[o]=t.basis.x.x;buffer[o+1]=t.basis.y.x;buffer[o+2]=t.basis.z.x;buffer[o+3]=t.origin.x
 buffer[o+4]=t.basis.x.y;buffer[o+5]=t.basis.y.y;buffer[o+6]=t.basis.z.y;buffer[o+7]=t.origin.y
 buffer[o+8]=t.basis.x.z;buffer[o+9]=t.basis.y.z;buffer[o+10]=t.basis.z.z;buffer[o+11]=t.origin.z
