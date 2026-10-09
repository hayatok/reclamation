extends SceneTree
const RunnerLibrary=preload('res://runner_pose_library.gd')
const NormalLibrary=preload('res://infected_pose_library.gd')
const Horde=preload('res://horde_renderer.gd')
const CorpseMotion=preload('res://corpse_motion.gd')
func _initialize():call_deferred('run')
func run():
 assert(NormalLibrary.configure('res://assets/models/infected_baked_poses.glb','res://assets/models/infected_baked_poses_far.glb'))
 var original_mesh=NormalLibrary.mesh_for('walk',0)
 assert(RunnerLibrary.configure())
 assert(original_mesh==NormalLibrary.mesh_for('walk',0),'Runner library must not replace normal pose storage')
 for far in [false,true]:
  for clip in RunnerLibrary.COUNTS:
   for frame in RunnerLibrary.COUNTS[clip]:
    var mesh:Mesh=RunnerLibrary.mesh_for(clip,frame,far)
    assert(mesh!=null and mesh.get_surface_count()==1)
    var arrays=mesh.surface_get_arrays(0)
    assert(arrays[Mesh.ARRAY_CUSTOM0].size()==arrays[Mesh.ARRAY_VERTEX].size()*3)
 assert(RunnerLibrary.sample('attack',0)==Vector3(0,1,0),'Damage timestamp begins at contact pose')
 assert(RunnerLibrary.sample('death',1.2)==Vector3(7,7,0))
 var stage=Node3D.new();root.add_child(stage)
 var horde=Horde.new();stage.add_child(horde)
 var enemies=[]
 for i in 4:
  var actor=Node3D.new();stage.add_child(actor)
  actor.position=Vector3(i*2,0,0)
  var e={'node':actor,'speed':2.7 if i in [1,2] else 1.65,'armored':i==3,'moving':true,'hp':100,'attack_at':-100.0}
  if i==2:e.merge({'life':3.25,'start':actor.transform,'scale':Vector3.ONE,'death_kind':&'ballistic','death_direction':Vector3.RIGHT})
  enemies.append(e)
 await process_frame
 assert(horde.baked.active and horde.baked_runner.active)
 var before=enemies.duplicate(true)
 horde.update_horde(enemies,1.0)
 assert(horde.baked.visible_count==1 and horde.baked_runner.visible_count==2)
 assert(horde._buckets[1].members.is_empty(),'No duplicate six-part runner draw')
 assert(horde._buckets[2].members.size()==1,'Armored fallback remains')
 assert(enemies==before,'Render step does not mutate combat dictionaries')
 var actor=enemies[1].node
 var old_phase=horde.baked_runner.gait_states[actor.get_instance_id()].cycle
 actor.position.z-=.172
 horde.update_horde(enemies,1.1)
 var gait=horde.baked_runner.gait_states[actor.get_instance_id()]
 var stature=.94+float(actor.get_instance_id()%7)*.02
 assert(gait.moving and is_equal_approx(fposmod(gait.cycle-old_phase,1.0),.1/stature))
 var previous=gait.cycle
 horde.update_horde(enemies,1.1)
 assert(horde.baked_runner.gait_states[actor.get_instance_id()].cycle==previous,'Paused renders cannot drift gait')
 enemies[1].attack_at=1.1
 horde.update_horde(enemies,1.1)
 assert(horde.baked_runner.members['attack_00_true'].size()==1)
 # Corpse roots already carry the procedural fall in main; baked rendering
 # must derive world placement from saved start/CopseMotion, not topple twice.
 var corpse=enemies[2]
 corpse.node.rotation.x=1.2
 horde.update_horde(enemies,1.2)
 var found=false
 for key in horde.baked_runner.members:
  if not key.begins_with('death_'):continue
  for member in horde.baked_runner.members[key]:
   if member[1]!=corpse.node.get_instance_id():continue
   var expected=CorpseMotion.apply_world(corpse.start,CorpseMotion.sample(corpse.death_kind,corpse.death_direction,.25))
   expected.basis=expected.basis.scaled(Vector3.ONE*(.94+float(corpse.node.get_instance_id()%7)*.02))
   assert(member[0].is_equal_approx(expected),'Baked runner corpse must avoid double topple')
   found=true
 assert(found)
 print('RUNNER_ART_CONTRACT_PASS: 56 shared pose meshes; independent normal cache; filters; travel gait; pause; immediate contact; saved-start corpse; no gameplay mutation')
 quit()
