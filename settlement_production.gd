extends RefCounted
## Building-local FIFO production. All persistent state lives in building queues.
## The host owns placement/navigation/rally application inside spawn_produced_unit.
## Host contract: units, buildings, settlement_age, stockpile; spend_cost,
## refund_cost, spawn_produced_unit, complete_age, production_notice.

const Rules = preload("settlement_rules.gd")
var host: Node

func setup(value: Node) -> void:
 host = value
 if not is_instance_valid(host):
  return
 for b in host.buildings:
  if b is Dictionary:
   _prepare_building(b)

func queue_unit(building: Dictionary, kind: String) -> bool:
 var check: Dictionary = can_queue_unit(building, kind)
 if not check.ok:
  _notice(check.reason)
  return false
 var rule: Dictionary = Rules.unit(kind)
 var paid: Dictionary = rule.cost.duplicate(true)
 if not host.spend_cost(paid):
  _notice("資材が不足しています: " + Rules.cost_text(paid))
  return false
 _prepare_building(building)
 building.queue.append({"id": kind, "type": "unit", "kind": kind, "remaining": float(rule.time), "duration": float(rule.time), "paid_cost": paid, "population": int(rule.population), "refunded": false, "waiting": ""})
 _notice("%s: %sを予約" % [Rules.building(building.kind).title, rule.title])
 return true

func queue_age(building: Dictionary) -> bool:
 var check: Dictionary = can_queue_age(building)
 if not check.ok:
  _notice(check.reason)
  return false
 var target: int = int(host.settlement_age) + 1
 var rule: Dictionary = Rules.age(target)
 var paid: Dictionary = rule.cost.duplicate(true)
 if not host.spend_cost(paid):
  _notice("資材が不足しています: " + Rules.cost_text(paid))
  return false
 _prepare_building(building)
 building.queue.append({"id": "age_%d" % target, "type": "age", "target_age": target, "remaining": float(rule.time), "duration": float(rule.time), "paid_cost": paid, "population": 0, "refunded": false, "waiting": ""})
 _notice("%sへの発展を予約" % rule.title)
 return true

func can_queue_unit(building: Dictionary, kind: String) -> Dictionary:
 var check: Dictionary = _check_producer(building)
 if not check.ok:
  return check
 var rule: Dictionary = Rules.unit(kind)
 if rule.is_empty() or str(rule.get("producer", "")).is_empty():
  return _blocked("訓練できないユニットです")
 if str(building.get("kind", "")) != str(rule.producer):
  return _blocked("%sで訓練できます" % Rules.building(rule.producer).title)
 if int(host.settlement_age) < int(rule.age):
  return _blocked("時代 %d が必要" % int(rule.age))
 var missing: Array[String] = Rules.missing_requirements(rule.prerequisites, host.buildings)
 if not missing.is_empty():
  return _blocked("必要施設: " + "、".join(missing))
 if not Rules.can_afford(host.stockpile, rule.cost):
  return _blocked("資材が不足しています: " + Rules.cost_text(rule.cost))
 return {"ok": true, "reason": ""}

func can_queue_age(building: Dictionary) -> Dictionary:
 var check: Dictionary = _check_producer(building)
 if not check.ok:
  return check
 if building.get("kind", "") != "hq":
  return _blocked("時代の発展は復興本部で行います")
 var target: int = int(host.settlement_age) + 1
 var rule: Dictionary = Rules.age(target)
 if rule.is_empty():
  return _blocked("最高段階に到達しています")
 if pending_age() > 0:
  return _blocked("時代の発展はすでに予約されています")
 var missing: Array[String] = Rules.missing_requirements(rule.prerequisites, host.buildings)
 if not missing.is_empty():
  return _blocked("必要施設: " + "、".join(missing))
 if not Rules.can_afford(host.stockpile, rule.cost):
  return _blocked("資材が不足しています: " + Rules.cost_text(rule.cost))
 return {"ok": true, "reason": ""}

func cancel_last(building: Dictionary) -> bool:
 if not is_instance_valid(host) or not _owns(building):
  return false
 _prepare_building(building)
 if building.queue.is_empty():
  return false
 var item: Dictionary = building.queue.pop_back()
 _refund_once(item)
 if building.queue.is_empty():
  _set_state(building, "idle")
 _notice("予約を取り消し、支払った資材を返却しました")
 return true

func on_building_destroyed(building: Dictionary) -> void:
 if not is_instance_valid(host) or building.is_empty():
  return
 _prepare_building(building)
 # Clear first: callbacks or repeated destruction notifications cannot refund twice.
 var abandoned: Array = building.queue.duplicate()
 building.queue.clear()
 building.production_destroyed = true
 _set_state(building, "destroyed")
 for value in abandoned:
  if value is Dictionary:
   _refund_once(value)
 if not abandoned.is_empty():
  _notice("生産施設を失いました。未完了の予約資材を返却しました")

func update(dt: float) -> void:
 if not is_instance_valid(host) or not is_finite(dt) or dt < 0.0:
  return
 # Snapshot the list, not the dictionaries: queue and status stay save-visible.
 for value in host.buildings.duplicate():
  if not value is Dictionary:
   continue
  var building: Dictionary = value
  _prepare_building(building)
  if building.get("production_destroyed", false):
   continue
  if float(building.get("hp", 0.0)) <= 0.0 or (building.has("node") and not is_instance_valid(building.node)):
   on_building_destroyed(building)
   continue
  if building.queue.is_empty():
   _set_state(building, "idle")
   continue
  if not Rules.is_completed(building):
   _set_state(building, "construction")
   continue
  if not bool(building.get("enabled", true)):
   _set_state(building, "disabled")
   continue
  if bool(Rules.building(str(building.get("kind", ""))).get("requires_power", false)) and not bool(building.get("powered", false)):
   _set_state(building, "unpowered")
   continue
  var budget: float = dt
  while not building.queue.is_empty():
   var item: Dictionary = building.queue[0]
   var remaining: float = maxf(0.0, float(item.get("remaining", 0.0)))
   var elapsed: float = minf(budget, remaining)
   item.remaining = maxf(0.0, remaining - elapsed)
   budget = maxf(0.0, budget - elapsed)
   if float(item.remaining) > 0.000001:
    item.waiting = ""
    _set_state(building, "working")
    break
   item.remaining = 0.0
   if not _finish(building, item):
    break
   if building.get("production_destroyed", false):
    break
   if budget <= 0.0:
    break
  if building.queue.is_empty() and not building.get("production_destroyed", false):
   _set_state(building, "idle")

func population_used() -> int:
 if not is_instance_valid(host):
  return 0
 var used: int = 0
 for value in host.units:
  if not value is Dictionary:
   continue
  var u: Dictionary = value
  if float(u.get("hp", 0.0)) <= 0.0:
   continue
  if u.has("node") and not is_instance_valid(u.node):
   continue
  used += maxi(0, int(Rules.unit(str(u.get("kind", ""))).get("population", 0)))
 return used

func population_cap() -> int:
 if not is_instance_valid(host):
  return 0
 var cap: int = 0
 for value in host.buildings:
  if value is Dictionary and Rules.is_completed(value):
   cap += maxi(0, int(Rules.building(str(value.get("kind", ""))).get("population_cap", 0)))
 return cap

func pending_age() -> int:
 if not is_instance_valid(host):
  return 0
 for building in host.buildings:
  if not building is Dictionary or building.get("production_destroyed", false) or float(building.get("hp", 0.0)) <= 0.0:
   continue
  for item in building.get("queue", []):
   if item is Dictionary and item.get("type", "") == "age":
    return int(item.get("target_age", 0))
 return 0

func available_actions(building: Dictionary) -> Array[Dictionary]:
 var actions: Array[Dictionary] = []
 if not is_instance_valid(host) or not _owns(building) or building.is_empty():
  return actions
 for kind in Rules.unit_kinds_for(str(building.get("kind", ""))):
  var rule: Dictionary = Rules.unit(kind)
  var check: Dictionary = can_queue_unit(building, kind)
  actions.append({"id": kind, "type": "unit", "title": rule.title, "cost": rule.cost.duplicate(true), "time": rule.time, "population": rule.population, "age": rule.age, "enabled": check.ok, "reason": check.reason})
 if building.get("kind", "") == "hq" and int(host.settlement_age) < 3:
  var target: int = int(host.settlement_age) + 1
  var rule: Dictionary = Rules.age(target)
  var check: Dictionary = can_queue_age(building)
  actions.append({"id": "age_%d" % target, "type": "age", "title": rule.title, "cost": rule.cost.duplicate(true), "time": rule.time, "population": 0, "age": target, "enabled": check.ok, "reason": check.reason})
 return actions

func _finish(building: Dictionary, item: Dictionary) -> bool:
 if item.get("type", "") == "unit":
  var kind: String = str(item.get("kind", item.get("id", "")))
  var rule: Dictionary = Rules.unit(kind)
  if rule.is_empty() or rule.get("producer", "") != building.get("kind", ""):
   return _discard_invalid(building, item)
  if int(host.settlement_age) < int(rule.age):
   return _wait_for(building, item, "age", "時代の条件を満たすまで待機")
  if population_used() + maxi(0, int(item.get("population", rule.population))) > population_cap():
   return _wait_for(building, item, "population", "人口枠が不足しています。住居を完成させてください")
  var produced: Dictionary = host.spawn_produced_unit(kind, building)
  if produced.is_empty():
   return _wait_for(building, item, "spawn_blocked", "出撃場所が空くまで待機")
  # A successful callback must add the live unit to host.units immediately.
  building.queue.pop_front()
  item.waiting = ""
  _set_state(building, "working")
  _notice("%sが到着しました" % rule.title)
  return true
 if item.get("type", "") == "age":
  var target: int = int(item.get("target_age", 0))
  var rule: Dictionary = Rules.age(target)
  if rule.is_empty() or building.get("kind", "") != "hq":
   return _discard_invalid(building, item)
  if target <= int(host.settlement_age):
   # Protect restored/external advances from paying twice for an existing age.
   building.queue.pop_front()
   _refund_once(item)
   return true
  if target != int(host.settlement_age) + 1:
   return _wait_for(building, item, "age", "前の時代の発展を待機")
  # Prerequisites are an enqueue gate. A paid research order survives their loss.
  building.queue.pop_front()
  host.complete_age(target)
  item.waiting = ""
  _set_state(building, "working")
  _notice("%sへ発展しました" % rule.title)
  return true
 return _discard_invalid(building, item)

func _wait_for(building: Dictionary, item: Dictionary, state: String, reason: String) -> bool:
 item.waiting = state
 var changed: bool = building.get("queue_state", "") != state
 _set_state(building, state)
 if changed:
  _notice(reason)
 return false

func _discard_invalid(building: Dictionary, item: Dictionary) -> bool:
 building.queue.pop_front()
 _refund_once(item)
 _notice("無効な予約を取り消し、支払った資材を返却しました")
 return true

func _refund_once(item: Dictionary) -> void:
 if bool(item.get("refunded", false)):
  return
 item.refunded = true
 var paid: Dictionary = item.get("paid_cost", {})
 if not paid.is_empty():
  host.refund_cost(paid.duplicate(true))

func _check_producer(building: Dictionary) -> Dictionary:
 if not is_instance_valid(host):
  return _blocked("生産システムが準備されていません")
 if building.is_empty() or not _owns(building):
  return _blocked("施設を選択してください")
 if not Rules.is_completed(building):
  return _blocked("完成した生産施設が必要です")
 if Rules.unit_kinds_for(str(building.get("kind", ""))).is_empty():
  return _blocked("この施設では訓練できません")
 if building.get("queue", []).size() >= Rules.MAX_QUEUE_SIZE:
  return _blocked("予約枠がいっぱいです (%d)" % Rules.MAX_QUEUE_SIZE)
 return {"ok": true, "reason": ""}

func _owns(building: Dictionary) -> bool:
 for value in host.buildings:
  if value is Dictionary and is_same(value, building):
   return true
 return false

func _prepare_building(building: Dictionary) -> void:
 if not building.has("queue"):
  building.queue = []
 if not building.has("rally"):
  var location: Vector3 = Vector3.ZERO
  if building.has("node") and is_instance_valid(building.node) and building.node is Node3D:
   location = building.node.position
  building.rally = location + Vector3(float(building.get("radius", 2.0)) + 2.0, 0.0, 0.0)
 if not building.has("rally_target"):
  building.rally_target = null
 if not building.has("queue_state"):
  building.queue_state = "idle"

func _set_state(building: Dictionary, state: String) -> void:
 building.queue_state = state
 var queue: Array = building.get("queue", [])
 if not queue.is_empty() and queue[0] is Dictionary:
  queue[0].waiting = state if state in ["unpowered", "construction", "disabled", "population", "spawn_blocked", "age"] else ""

func _notice(message: String) -> void:
 if is_instance_valid(host) and host.has_method("production_notice"):
  host.production_notice(message)

func _blocked(reason: String) -> Dictionary:
 return {"ok": false, "reason": reason}
