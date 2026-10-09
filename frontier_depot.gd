extends RefCounted
## Optional fixed-site restoration. Reclaimed site records are inert tombstones;
## all delivery, damage, repairs and refunds belong to the ordinary depot.
const KIND:String="abandoned_depot"
const POSITION:Vector3=Vector3(-50,0,-8)
const COST:Dictionary={"salvage":50,"parts":10}
const WORK_SECONDS:float=12.0
const Structures=preload("res://structure_visuals.gd")
const Orders=preload("res://worker_orders.gd")

static func retired(site:Dictionary)->bool:
 return site.get("kind","")==KIND and bool(site.get("reclaimed",false))

static func add_visual(parent:Node3D):
 Structures.add_building(parent,"depot")
 for mesh in parent.find_children("*","MeshInstance3D",true,false):
  for index in mesh.mesh.get_surface_count():
   var original=mesh.get_active_material(index)
   if original is StandardMaterial3D:
    var worn=original.duplicate() as StandardMaterial3D
    worn.albedo_color*=Color(.55,.57,.52,1);worn.roughness=1
    mesh.set_surface_override_material(index,worn)
 # Two boarded door braces distinguish the disused shell at ordinary zoom.
 var material=StandardMaterial3D.new();material.albedo_color=Color("716045");material.roughness=1
 for side in [-1,1]:
  var brace=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=Vector3(2.2,.16,.12)
  brace.mesh=shape;brace.material_override=material;brace.position=Vector3(0,1,1.45);brace.rotation.z=side*.52
  parent.add_child(brace)
 parent.visible=false

static func apply_retired(site:Dictionary):
 if not retired(site):return
 site.node.hide();site.erase("nav_half_extents")

static func complete(host:Node3D,site:Dictionary):
 if retired(site) or not site.get("paid",false) or site.get("progress",0)<1:return
 site.reclaimed=true;site.progress=1.0
 # Remove reservations before replacing the physical footprint.
 for worker in host.units:
  if worker.kind=="worker" and worker.task=="site" and worker.target==site:
   Orders.finish(host,worker,true)
 apply_retired(site)
 var depot=host.make_building("depot",site.node.position,true)
 depot.paid_resources=COST.duplicate()
 if host.inspected_site==site:
  host.inspected_site={};host.inspected=depot
 host.context_signature=""
 host.pulse(site.node.position,host.CYAN,5,1);host.tone("power")
 host.notify("廃棄倉庫を復旧：資源の搬入が可能",5)
