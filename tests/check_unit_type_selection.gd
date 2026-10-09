extends SceneTree
const Selection=preload("res://unit_type_selection.gd")
var failures:int=0
var checks:int=0
var world:SubViewport

func _initialize():call_deferred("run")

func check(ok:bool,message:String):
 checks+=1
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1

func unit(kind:String,position:Vector3,hp:float=50.0)->Dictionary:
 var node=Node3D.new()
 world.add_child(node)
 node.position=position
 return {"node":node,"kind":kind,"hp":hp,"task":"escort","goal":Vector3(7,0,3),"route":[Vector3(2,0,2)],"cargo":{"wood":4},"jobs":[{"kind":"repair"}],"cd":0.75}

func run():
 world=SubViewport.new()
 world.size=Vector2i(800,600)
 world.own_world_3d=true
 root.add_child(world)
 var camera=Camera3D.new()
 world.add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=20.0
 camera.position=Vector3(0,0.8,10)
 camera.near=0.1
 camera.far=100.0
 camera.make_current()
 await process_frame
 var guard=unit("guard",Vector3.ZERO)
 var near_guard=unit("guard",Vector3(0.3,0,0))
 var grenade=unit("grenade",Vector3(2,0,0))
 var cart=unit("siegecart",Vector3(-2,0,0))
 var worker=unit("worker",Vector3(0,0,2))
 var truck=unit("truck",Vector3(0,0,-2))
 var convoy=unit("convoy",Vector3.ZERO)
 var outside=unit("guard",Vector3(40,0,0))
 var behind=unit("guard",Vector3(0,0,20))
 var beyond_far=unit("guard",Vector3(0,0,-120))
 var before_near=unit("guard",Vector3(0,0,9.95))
 var dead=unit("guard",Vector3.ZERO,0)
 var flagged_dead=unit("guard",Vector3.ZERO)
 flagged_dead.dead=true
 var queued=unit("guard",Vector3.ZERO)
 queued.node.queue_free()
 var freed=unit("guard",Vector3.ZERO)
 freed.node.free()
 var invalid={"kind":"guard","hp":50,"node":null}
 var units:Array=[convoy,dead,flagged_dead,queued,freed,invalid,behind,beyond_far,before_near,guard,near_guard,grenade,cart,worker,truck,outside]
 var before:Array=units.duplicate(true)
 var center:Vector2=camera.unproject_position(guard.node.position+Vector3(0,0.8,0))
 check(is_same(Selection.point_unit(units,camera,center),guard),"point skips convoy, dead, queued, freed, invalid and camera-clipped candidates")
 check(is_same(Selection.point_unit(units,camera,camera.unproject_position(near_guard.node.position+Vector3(0,0.8,0))),near_guard),"point chooses closest living unit")
 check(is_same(Selection.point_unit([guard],camera,center,0.1),guard),"point matches the existing selection center offset")
 check(Selection.point_unit([guard],camera,camera.unproject_position(guard.node.position),1).is_empty(),"point does not silently use the unit foot position")
 check(Selection.point_unit([guard],camera,center+Vector2(24,0)).is_empty(),"default 24-pixel radius retains the existing strict boundary")
 check(Selection.point_unit([guard],camera,center,0).is_empty(),"nonpositive pick radius returns no unit")
 check(Selection.point_unit(units,null,center).is_empty(),"missing camera returns no unit")
 check(Selection.point_unit(units,camera,Vector2(-100,-100)).is_empty(),"empty-screen click returns no unit")
 var view=Rect2(Vector2.ZERO,Vector2(800,600))
 check(Selection.same_kind_in_view(units,guard,camera,view)==[guard,near_guard],"same-kind view keeps exact guards and excludes offscreen, clipped and invalid units")
 check(Selection.same_kind_in_view(units,grenade,camera,view)==[grenade],"grenadiers remain distinct from guards")
 check(Selection.same_kind_in_view(units,cart,camera,view)==[cart],"siege carts remain distinct from guards")
 var narrow=Rect2(center-Vector2.ONE,Vector2(2,2))
 check(Selection.same_kind_in_view(units,guard,camera,narrow)==[guard],"caller viewport limits same-kind selection")
 check(Selection.same_kind_in_view(units,convoy,camera,view).is_empty() and Selection.same_kind_in_view(units,dead,camera,view).is_empty(),"convoy and dead anchors produce no selection")
 check(Selection.same_kind_in_view(units,guard,null,view).is_empty(),"missing camera yields an empty same-kind selection")
 var mixed:Array=[guard,grenade,cart,near_guard]
 for index in 10:mixed.append(unit("guard",Vector3(index,0,1)))
 var second_grenade=unit("grenade",Vector3(1,0,1))
 mixed.append(second_grenade)
 var mixed_before:Array=mixed.duplicate(true)
 check(Selection.groups(mixed)==[{"kind":"guard","count":12},{"kind":"grenade","count":2},{"kind":"siegecart","count":1}],"mixed army reports exact 12 guards, 2 grenadiers and 1 cart")
 check(Selection.groups([grenade,guard,worker,truck,near_guard])==[{"kind":"grenade","count":1},{"kind":"guard","count":2},{"kind":"worker","count":1},{"kind":"truck","count":1}],"groups preserve first-selected kind order including noncombat units")
 check(Selection.groups([convoy,dead,flagged_dead,queued,freed,invalid,{},null]).is_empty(),"groups omit unselectable and malformed entries")
 check(Selection.of_kind(mixed,"grenade")==[grenade,second_grenade],"mobile filter contains only grenadiers already selected")
 check(Selection.of_kind([near_guard],"guard")==[near_guard],"filter does not add other same-kind world units")
 check(Selection.of_kind([guard,outside],"guard")==[guard,outside],"filter retains selected offscreen members without a camera query")
 check(Selection.of_kind(mixed,"siegecart")==[cart] and Selection.of_kind(mixed,"missing").is_empty(),"filter uses exact kinds and handles absent kinds")
 check(Selection.of_kind([convoy,dead,flagged_dead,queued,freed,invalid],"guard").is_empty(),"filter excludes stale or dead selections")
 check(is_same(Selection.of_kind(mixed,"grenade")[0],grenade) and is_same(Selection.same_kind_in_view(units,guard,camera,view)[0],guard),"results retain actual dictionary identities")
 check(units==before and mixed==mixed_before,"all queries preserve source arrays, unit jobs, orders, cargo and cooldowns")
 var filtered:Array=Selection.of_kind(mixed,"grenade")
 filtered.clear()
 check(mixed==mixed_before,"returned result arrays are independent of the current selection")
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 check(Selection.same_kind_in_view(units,guard,camera,view)==[guard,near_guard],"camera clipping also works with perspective projection")
 print("UNIT_TYPE_SELECTION_RESULT checks=",checks," failures=",failures)
 world.free()
 quit(1 if failures else 0)
