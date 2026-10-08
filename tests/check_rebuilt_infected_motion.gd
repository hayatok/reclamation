extends SceneTree
const Renderer=preload('res://baked_infected_renderer.gd')
const Library=preload('res://infected_pose_library.gd')
func _initialize():
 assert(Library.configure('res://assets/models/infected_baked_poses.glb','res://assets/models/infected_baked_poses_far.glb'))
 var s=Renderer.advance_gait({},Vector3.ZERO,0,1.12,1.65,.2)
 assert(not s.moving)
 s=Renderer.advance_gait(s,Vector3(0,0,.112),.1,1.12,1.65,.2)
 assert(s.moving and is_equal_approx(s.cycle,.3))
 var paused=Renderer.advance_gait(s,s.position,.1,1.12,1.65,.2)
 assert(paused.moving and paused.cycle==s.cycle)
 var stopped=Renderer.advance_gait(s,s.position,.2,1.12,1.65,.2)
 assert(not stopped.moving and stopped.cycle==s.cycle)
 var teleported=Renderer.advance_gait(s,Vector3(20,0,0),.2,1.12,1.65,.2)
 assert(not teleported.moving and teleported.cycle==s.cycle)
 var reset=Renderer.advance_gait(s,Vector3.ZERO,-1,1.12,1.65,.2)
 assert(not reset.moving and is_equal_approx(reset.cycle,.2))
 for distant in [false,true]:
  for clip in Library.COUNTS:
   for frame in Library.COUNTS[clip]:assert(Library.mesh_for(clip,frame,distant)!=null)
 print('REBUILT_INFECTED_MOTION_PASS: distance gait, pause, stop, teleport, reset, 64 shared pose surfaces')
 quit()
