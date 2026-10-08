extends SceneTree
func _initialize():call_deferred("run")
func run():
 var lib=load('res://infected_pose_library.gd')
 assert(lib.configure('res://assets/models/infected_baked_poses.glb','res://assets/models/infected_baked_poses_far.glb'))
 for far in [false,true]:
  var material=lib.mesh_for('walk',0,far).surface_get_material(0)
  var texture=material.get_shader_parameter('albedo_texture')
  assert(texture!=null and texture.get_width()>0)
  print('PACKED_INFECTED_ATLAS far=',far,' path=',texture.resource_path,' width=',texture.get_width())
 assert(ResourceLoader.exists('res://assets/ReclamationUIJP-Regular.otf'))
 assert(not ResourceLoader.exists('res://assets/Japanese.ttc'))
 var campaign=root.get_node('Campaign');campaign.launch=true;campaign.resume=false;campaign.muted=true
 var game=load('res://main.tscn').instantiate();root.add_child(game);current_scene=game
 print('PACKED_GAME_BOOT units=',game.units.size(),' infected_active=',game.horde_renderer.baked.active)
 quit()
