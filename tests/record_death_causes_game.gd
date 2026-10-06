extends "res://main.gd"
var death_counts:Dictionary={}
var admitted_counts:Dictionary={}
func hit(e:Dictionary,damage:float,direct:bool,generation:int=0,electric:bool=false,critical:bool=false,visual_origin:Vector3=Vector3.INF,visual_kind:StringName=&""):
 var was_alive=not e.dead
 super.hit(e,damage,direct,generation,electric,critical,visual_origin,visual_kind)
 if was_alive and e.dead:
  var kind=visual_kind if visual_kind!=&"" else &"electric" if electric else &"explosive" if generation>0 else &"ballistic"
  death_counts[kind]=int(death_counts.get(kind,0))+1
  if corpses.any(func(corpse):return corpse.node==e.node):admitted_counts[kind]=int(admitted_counts.get(kind,0))+1
