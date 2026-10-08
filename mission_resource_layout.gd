extends RefCounted
## Authored deposits; no runtime RNG or changes to gathering rules.
## Mission 2 splits its finite parts supply between two defensible freight zones.
const BASE:Array = [
 {"id":"home_food","kind":"food","pos":Vector3(-8,0,11),"stock":1200.0},
 {"id":"home_salvage","kind":"salvage","pos":Vector3(8,0,11),"stock":1800.0},
 {"id":"home_parts","kind":"parts","pos":Vector3(-11,0,2),"stock":600.0},
 {"id":"south_food","kind":"food","pos":Vector3(18,0,18),"stock":1600.0},
 {"id":"west_salvage","kind":"salvage","pos":Vector3(-20,0,15),"stock":2200.0},
 {"id":"east_parts","kind":"parts","pos":Vector3(18,0,-1),"stock":1000.0},
 {"id":"north_salvage","kind":"salvage","pos":Vector3(-7,0,-16),"stock":2600.0},
 {"id":"north_food","kind":"food","pos":Vector3(0,0,-24),"stock":2000.0},
 {"id":"outer_parts","kind":"parts","pos":Vector3(-20,0,-15),"stock":1200.0},
]
static func for_mission(index:int)->Array:
 if index!=1:return BASE.duplicate(true)
 return [
  {"id":"home_food","kind":"food","pos":Vector3(-72,0,51),"stock":1200.0},
  {"id":"home_salvage","kind":"salvage","pos":Vector3(-56,0,51),"stock":1800.0},
  {"id":"home_parts","kind":"parts","pos":Vector3(-75,0,42),"stock":600.0},
  {"id":"north_food","kind":"food","pos":Vector3(-52,0,-14),"stock":1600.0},
  {"id":"north_salvage","kind":"salvage","pos":Vector3(-58,0,-24),"stock":2200.0},
  {"id":"north_parts","kind":"parts","pos":Vector3(-38,0,-18),"stock":1000.0},
  {"id":"east_food","kind":"food","pos":Vector3(24,0,30),"stock":2000.0},
  {"id":"east_salvage","kind":"salvage","pos":Vector3(42,0,30),"stock":2600.0},
  {"id":"east_parts","kind":"parts","pos":Vector3(30,0,12),"stock":1200.0},
 ]
