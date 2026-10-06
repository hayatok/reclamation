extends "res://main.gd"
## Review-only instrumentation. No actors, resources or damage are injected.
var legacy_aim := false
var aim_samples:Array=[]
var impact_samples:Array=[]
var aim_costs:Array=[]
var heavy_ammo_spent:float=0.0
func auto_fire_target(p:Vector3,radius:float,kind:String)->Variant:
 var started=Time.get_ticks_usec()
 var result=nearest_enemy(p,radius) if legacy_aim else super.auto_fire_target(p,radius,kind)
 if kind in ["grenade","siegecart","mortar"]:aim_costs.append({"enemies":enemies.size(),"us":Time.get_ticks_usec()-started})
 return result
func fire(origin:Vector3,target:Dictionary,base:float,kind:String,source:Dictionary={}):
 if kind in ["grenade","mortar"]:
  var blast_radius=(3.0 if kind=="grenade" else 4.1)*(1+bonus("blast_radius","blast_radius_add"))
  var covered=0
  for enemy in enemies:
   if not enemy.dead and enemy.node.position.distance_to(target.node.position)<blast_radius:covered+=1
  aim_samples.append({"time":elapsed,"kind":source.get("kind",kind),"target":vec_data(target.node.position),"blast_radius":blast_radius,"living_footprint_at_launch":covered,"task":source.get("task","")})
 var ammo_before=ammo
 super.fire(origin,target,base,kind,source)
 if kind in ["grenade","mortar"]:heavy_ammo_spent+=ammo_before-ammo
func detonate_shell(shell:Dictionary):
 var before=kills
 super.detonate_shell(shell)
 impact_samples.append({"time":elapsed,"kind":shell.kind,"target":vec_data(shell.to),"immediate_kills":kills-before})
