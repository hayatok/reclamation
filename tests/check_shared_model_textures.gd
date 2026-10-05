extends SceneTree

var failures:Array[String]=[]
var checked_meshes:int=0
var shared_hits:int=0
var unique_textures:Dictionary={}

func _initialize():call_deferred("run")

func run():
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/SHARED_MODEL_TEXTURES.json"))
 var aliases:Dictionary=report.export_excluded_aliases
 var canonical:Dictionary={}
 for path in aliases.values():canonical["res://"+str(path)]=true
 for model in report.models:
  var packed:PackedScene=load("res://"+str(model))
  if packed==null:
   failures.append("Unable to load "+str(model));continue
  var instance=packed.instantiate()
  var prior_hits=shared_hits
  inspect(instance,aliases,canonical)
  if shared_hits==prior_hits:failures.append("No shared texture in "+str(model))
  instance.free()
 print(JSON.stringify({"models":report.models.size(),"meshes":checked_meshes,"shared_texture_uses":shared_hits,"unique_texture_paths":unique_textures.size(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)

func inspect(node:Node,aliases:Dictionary,canonical:Dictionary):
 if node is MeshInstance3D and node.mesh!=null:
  checked_meshes+=1
  for surface in node.mesh.get_surface_count():
   var material:Material=node.get_active_material(surface)
   if material is BaseMaterial3D:
    for property in ["albedo_texture","normal_texture","metallic_texture","roughness_texture","ao_texture"]:
     var texture:Texture2D=material.get(property)
     if texture==null:continue
     var path=texture.resource_path
     if aliases.has(path.trim_prefix("res://")):failures.append("Excluded alias still referenced: "+path)
     unique_textures[path]=true
     if canonical.has(path):
      shared_hits+=1
      if texture!=load(path):failures.append("Texture is not shared through ResourceLoader: "+path)
 for child in node.get_children():inspect(child,aliases,canonical)
