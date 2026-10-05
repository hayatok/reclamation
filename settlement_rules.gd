extends RefCounted
## Single source of truth for settlement commands, construction and production.
## Legacy `tech` aliases the settlement age; all `cost` values are resource vectors.

const RESOURCE_KINDS: Array[String] = ["food", "salvage", "parts"]
const RESOURCE_TITLES = {"food": "食料", "salvage": "廃材", "parts": "部品"}
const RESOURCE_RULES = {
 "food": {"rate": 1.2, "capacity": 10.0},
 "salvage": {"rate": 1.0, "capacity": 12.0},
 "parts": {"rate": 0.55, "capacity": 8.0}
}
const STARTING_STOCKPILE = {"food": 220.0, "salvage": 200.0, "parts": 30.0}
const STARTING_UNITS = {"worker": 6, "guard": 2}
const MAX_QUEUE_SIZE: int = 12

const UNITS = {
 "worker": {"title": "作業員", "title_en": "Worker", "hp": 100.0, "speed": 4.0, "damage": 0.0, "range": 0.0, "cooldown": 1.0, "cost": {"food": 50}, "time": 18.0, "population": 1, "age": 1, "tech": 1, "producer": "hq", "prerequisites": []},
 "guard": {"title": "生存者", "title_en": "Defender", "hp": 100.0, "speed": 4.4, "damage": 18.0, "range": 10.5, "cooldown": 0.72, "cost": {"food": 60, "salvage": 25}, "time": 22.0, "population": 1, "age": 1, "tech": 1, "producer": "barracks", "prerequisites": []},
 "grenade": {"title": "爆薬手", "title_en": "Grenadier", "hp": 120.0, "speed": 3.8, "damage": 56.0, "range": 13.0, "cooldown": 2.3, "cost": {"food": 80, "salvage": 50, "parts": 20}, "time": 32.0, "population": 1, "age": 2, "tech": 2, "producer": "barracks", "prerequisites": []},
 "truck": {"title": "補給車", "title_en": "Supply Truck", "hp": 180.0, "speed": 3.5, "damage": 0.0, "range": 0.0, "cooldown": 1.0, "cost": {"food": 100, "salvage": 100, "parts": 40}, "time": 40.0, "population": 2, "age": 2, "tech": 2, "producer": "vehicle_workshop", "prerequisites": []},
 "siegecart": {"title": "移動迫撃車", "title_en": "Siege Cart", "hp": 240.0, "speed": 2.7, "damage": 96.0, "range": 22.0, "cooldown": 3.4, "splash_radius": 4.5, "cost": {"food": 120, "salvage": 180, "parts": 100}, "time": 52.0, "population": 3, "age": 3, "tech": 3, "producer": "vehicle_workshop", "prerequisites": []},
 "convoy": {"title": "輸送隊", "title_en": "Convoy", "hp": 1000.0, "speed": 1.35, "damage": 0.0, "range": 0.0, "cooldown": 1.0, "cost": {}, "time": 0.0, "population": 0, "age": 1, "tech": 1, "producer": "", "prerequisites": []}
}

const BUILDINGS = {
 "hq": {"title": "復興本部", "title_en": "Headquarters", "hp": 900.0, "radius": 3.0, "cost": {}, "time": 0.0, "build_time": 0.0, "power": 0.0, "age": 1, "tech": 1, "population_cap": 10, "dropoff": true, "buildable": false, "category": "economy", "prerequisites": []},
 "house": {"title": "住居", "title_en": "House", "hp": 180.0, "radius": 1.7, "cost": {"salvage": 40}, "time": 20.0, "build_time": 20.0, "power": 0.0, "age": 1, "tech": 1, "population_cap": 5, "dropoff": false, "buildable": true, "category": "economy", "prerequisites": []},
 "depot": {"title": "資材集積所", "title_en": "Depot", "hp": 260.0, "radius": 1.8, "cost": {"salvage": 60}, "time": 25.0, "build_time": 25.0, "power": 0.0, "age": 1, "tech": 1, "population_cap": 0, "dropoff": true, "buildable": true, "category": "economy", "prerequisites": []},
 "garden": {"title": "共同菜園", "title_en": "Garden", "hp": 150.0, "radius": 2.0, "cost": {"salvage": 60}, "time": 30.0, "build_time": 30.0, "power": 0.0, "age": 1, "tech": 1, "population_cap": 0, "dropoff": false, "buildable": true, "category": "economy", "resource": "food", "renewable": true, "prerequisites": []},
 "barracks": {"title": "訓練所", "title_en": "Training Shelter", "hp": 340.0, "radius": 2.4, "cost": {"salvage": 100}, "time": 30.0, "build_time": 30.0, "power": 0.0, "age": 1, "tech": 1, "population_cap": 0, "dropoff": false, "buildable": true, "category": "military", "prerequisites": []},
 "vehicle_workshop": {"title": "車両工房", "title_en": "Vehicle Workshop", "requires_power": true, "hp": 420.0, "radius": 2.6, "cost": {"salvage": 180, "parts": 60}, "time": 45.0, "build_time": 45.0, "power": 2.0, "age": 2, "tech": 2, "population_cap": 0, "dropoff": false, "buildable": true, "category": "military", "prerequisites": [{"kind": "barracks", "count": 1}]},
 "tower": {"title": "監視塔", "title_en": "Watchtower", "hp": 220.0, "radius": 1.3, "cost": {"salvage": 65}, "time": 25.0, "build_time": 25.0, "power": 1.0, "age": 1, "tech": 1, "population_cap": 0, "dropoff": false, "buildable": true, "category": "defense", "prerequisites": []},
 "wall": {"title": "防壁", "title_en": "Barricade", "hp": 320.0, "radius": 1.0, "cost": {"salvage": 18}, "time": 12.0, "build_time": 12.0, "power": 0.0, "age": 1, "tech": 1, "population_cap": 0, "dropoff": false, "buildable": true, "category": "defense", "prerequisites": []},
 "factory": {"title": "弾薬工房", "title_en": "Ammunition Workshop", "hp": 280.0, "radius": 1.8, "cost": {"salvage": 120, "parts": 40}, "time": 35.0, "build_time": 35.0, "power": 2.0, "age": 2, "tech": 2, "population_cap": 0, "dropoff": false, "buildable": true, "category": "support", "prerequisites": [{"kind": "depot", "count": 1}]},
 "relay": {"title": "電力中継器", "title_en": "Power Relay", "hp": 180.0, "radius": 1.0, "cost": {"salvage": 50, "parts": 15}, "time": 20.0, "build_time": 20.0, "power": 0.5, "age": 2, "tech": 2, "population_cap": 0, "dropoff": false, "buildable": true, "category": "support", "prerequisites": []},
 "yard": {"title": "修復ヤード", "title_en": "Recovery Yard", "hp": 300.0, "radius": 2.0, "cost": {"salvage": 120, "parts": 45}, "time": 40.0, "build_time": 40.0, "power": 1.0, "age": 2, "tech": 2, "population_cap": 0, "dropoff": false, "buildable": true, "category": "support", "prerequisites": []},
 "mortar": {"title": "固定迫撃砲", "title_en": "Mortar Emplacement", "hp": 280.0, "radius": 1.7, "cost": {"salvage": 160, "parts": 65}, "time": 38.0, "build_time": 38.0, "power": 2.0, "age": 2, "tech": 2, "population_cap": 0, "dropoff": false, "buildable": true, "category": "defense", "prerequisites": [{"kind": "barracks", "count": 1}]}
}

const BUILD_ORDER: Array[String] = ["house", "depot", "garden", "barracks", "vehicle_workshop", "tower", "wall", "factory", "relay", "yard", "mortar"]
const AGES = {
 1: {"title": "I 開拓地", "title_en": "I — Settlement", "cost": {}, "time": 0.0, "producer": "hq", "prerequisites": []},
 2: {"title": "II 復興拠点", "title_en": "II — Recovery Hub", "cost": {"food": 350, "salvage": 100, "parts": 80}, "time": 70.0, "producer": "hq", "prerequisites": [{"kind": "house", "count": 2}, {"kind": "barracks", "count": 1}, {"kind": "depot", "count": 1}]},
 3: {"title": "III 機械化都市", "title_en": "III — Mechanized City", "cost": {"food": 800, "salvage": 400, "parts": 250}, "time": 100.0, "producer": "hq", "prerequisites": [{"kind": "factory", "count": 1, "powered": true}, {"kind": "vehicle_workshop", "count": 1}]}
}

static func unit(kind: String) -> Dictionary:
 return UNITS.get(kind, {})

static func building(kind: String) -> Dictionary:
 return BUILDINGS.get(kind, {})

static func age(stage: int) -> Dictionary:
 return AGES.get(stage, {})

static func unit_kinds_for(producer: String) -> Array[String]:
 var result: Array[String] = []
 for kind in UNITS:
  if not producer.is_empty() and UNITS[kind].producer == producer:
   result.append(kind)
 return result

static func worker_buildings(settlement_age: int) -> Array[String]:
 var result: Array[String] = []
 for kind in BUILD_ORDER:
  if int(BUILDINGS[kind].age) <= settlement_age:
   result.append(kind)
 return result

static func is_completed(b: Dictionary) -> bool:
 if b.is_empty() or float(b.get("hp", 0.0)) <= 0.0 or float(b.get("built", 0.0)) < 1.0 or b.get("production_destroyed", false):
  return false
 if b.has("node") and not is_instance_valid(b.node):
  return false
 return true

static func completed_count(kind: String, buildings: Array, powered: bool = false) -> int:
 var count: int = 0
 for value in buildings:
  if not value is Dictionary:
   continue
  var b: Dictionary = value
  if b.get("kind", "") == kind and is_completed(b) and (not powered or bool(b.get("powered", false))):
   count += 1
 return count

static func requirements_met(requirements: Array, buildings: Array) -> bool:
 return missing_requirements(requirements, buildings).is_empty()

static func missing_requirements(requirements: Array, buildings: Array) -> Array[String]:
 var missing: Array[String] = []
 for requirement in requirements:
  var kind: String = str(requirement.get("kind", ""))
  var powered: bool = bool(requirement.get("powered", false))
  var needed: int = int(requirement.get("count", 1))
  var current: int = completed_count(kind, buildings, powered)
  if current < needed:
   missing.append("%s%s %d/%d" % ["給電中の" if powered else "", building(kind).get("title", kind), current, needed])
 return missing

static func requirement_action(requirements:Array,buildings:Array)->String:
 for requirement in requirements:
  var kind:String=str(requirement.get("kind",""))
  var needed:int=int(requirement.get("count",1))
  var powered:bool=bool(requirement.get("powered",false))
  if completed_count(kind,buildings,powered)>=needed:continue
  var title:String=str(building(kind).get("title",kind))
  var ready:int=completed_count(kind,buildings)
  if powered and ready>=needed:return title+"に給電"
  var underway:int=0
  for value in buildings:
   if not value is Dictionary:continue
   if value.get("kind","")!=kind or float(value.get("hp",0.0))<=0 or value.get("production_destroyed",false):continue
   if value.has("node") and not is_instance_valid(value.node):continue
   if float(value.get("built",0.0))<1.0:underway+=1
  if ready+underway>=needed:return title+"を完成"
  return title+"を建設"
 return ""

static func can_build(kind: String, settlement_age: int, buildings: Array) -> Dictionary:
 var rule: Dictionary = building(kind)
 if rule.is_empty() or not rule.get("buildable", false):
  return {"ok": false, "reason": "建設できない施設です"}
 if settlement_age < int(rule.age):
  return {"ok": false, "reason": "時代 %d が必要" % int(rule.age)}
 var missing: Array[String] = missing_requirements(rule.prerequisites, buildings)
 if not missing.is_empty():
  return {"ok": false, "reason": "必要施設: " + "、".join(missing)}
 return {"ok": true, "reason": ""}

static func cost_text(cost: Dictionary) -> String:
 var pieces: Array[String] = []
 for resource in RESOURCE_KINDS:
  var amount: float = float(cost.get(resource, 0.0))
  if amount > 0.0:
   pieces.append("%s %d" % [RESOURCE_TITLES[resource], int(ceil(amount))])
 return " / ".join(pieces) if not pieces.is_empty() else "無料"

static func can_afford(stockpile: Dictionary, cost: Dictionary) -> bool:
 for resource in cost:
  if float(cost[resource]) < 0.0 or float(stockpile.get(resource, 0.0)) + 0.00001 < float(cost[resource]):
   return false
 return true
