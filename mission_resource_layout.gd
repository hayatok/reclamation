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
 var result=BASE.duplicate(true)
 if index!=1:return result
 for deposit in result:
  match deposit.id:
   "home_parts":deposit.stock=300.0
   "east_parts":deposit.pos=Vector3(11,0,-11)
   "outer_parts":
    deposit.pos=Vector3(-22,0,12)
    deposit.stock=1500.0
 return result
