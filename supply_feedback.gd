extends RefCounted
## Presentation-only observer. No host, scene, stockpile, RNG or save references.
## Record actual credits/debits at their mutation sites, then finish_step once
## per simulation tick. Only completed one-second buckets drive the display.

const WINDOW_SECONDS := 12
const RECOVERY_SECONDS := 3
const ENTRY_CHECKS := 2
const MIN_COMBAT_SECONDS := 6
const MIN_DEFICIT := 3.0
const ENTRY_RATIO := 1.10
const EPSILON := 0.000001
const STOP_PRIORITY := ["資材不足", "未給電", "手動停止", "建設中"]

var _buckets: Array[Dictionary] = []
var _current: Dictionary = _empty_bucket()
var _fraction := 0.0
var _entry_checks := 0
var _deficit := false
var _state := "quiet"


func reset() -> void:
	_buckets.clear()
	_current = _empty_bucket()
	_fraction = 0.0
	_entry_checks = 0
	_deficit = false
	_state = "quiet"


## The positive amount actually credited after the 400 cap, not the nominal
## rate and not an inventory difference sampled across unrelated operations.
func record_supply(credited: float, source: String) -> void:
	if not is_finite(credited) or credited <= 0.0:
		return
	if source == "base":
		_current.base += credited
	elif source == "factory":
		_current.factory += credited


## Only call for a supplied shot, with the exact discounted amount debited.
## Extra salvo/piercing targets do not spend again and must not be recorded.
func record_combat_spend(debited: float) -> void:
	if is_finite(debited) and debited > 0.0:
		_current.spent += debited


## An existing unsupplied fire() branch is a fact, not an inferred demand rate.
## Keep it separate: reserve fire consumes no stock and otherwise hides shortage.
func record_reserve_shot() -> void:
	_current.reserve_shots += 1


## Call after simulate(STEP), including its early-return paths. The gameplay
## clock is authoritative: do not call during pause, menus or growth choices.
## The production game uses fixed steps <= 1 second. A gap/invalid sample resets
## the display instead of inventing a distribution of events over missing time.
func finish_step(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0 or dt > 1.0:
		reset()
		return
	_fraction += dt
	if _fraction + EPSILON < 1.0:
		return
	_fraction = maxf(0.0, _fraction - 1.0)
	_buckets.append(_current)
	_current = _empty_bucket()
	if _buckets.size() > WINDOW_SECONDS:
		_buckets.pop_front()
	_evaluate()


## Pass CURRENT factory_status() strings from live owned factories. This is a
## fresh contextual snapshot, not historical evidence explaining the deficit.
## Returned data is detached; the observer does not retain the caller's array.
func view(workshop_states: Array[String] = []) -> Dictionary:
	var totals := _totals(WINDOW_SECONDS)
	var workshop := _workshop_context(workshop_states)
	var active := _state != "quiet"
	var issue := "予備弾使用" if _state == "reserve" else "消費超過"
	var caption := "弾薬"
	var context := ""
	var tooltip := ""
	if active:
		# Replace the narrow desktop caption; its existing ammo icon keeps context.
		caption = "予備弾使用" if _state == "reserve" else "消費超過"
		context = issue + " / " + str(workshop.hint)
		tooltip = "直近%d秒: 消費%.1f / 補給%.1f（基本%.1f・工房%.1f）。" % [
			int(totals.seconds), float(totals.spent), float(totals.supplied),
			float(totals.base), float(totals.factory)]
		if _state == "reserve":
			tooltip += "\n直近3秒に予備弾で射撃（威力40%）。"
		tooltip += "\n現在: " + str(workshop.hint) + "。"
	return {
		"state": _state,
		"active": active,
		"caption": caption,
		"issue": issue if active else "",
		"context": context,
		"tooltip": tooltip,
		"workshop_hint": workshop.hint,
		"workshop_counts": workshop.counts,
		"observed": totals,
		"bucket_count": _buckets.size(),
	}


func _evaluate() -> void:
	var recent := _totals(RECOVERY_SECONDS)
	# This is directly observed reserve fire; it needs no twelve-second estimate.
	# Three observed seconds prevent a startup/transient flash. It expires after
	# three completed seconds without reserve fire, even if old deficit remains.
	if _buckets.size() >= RECOVERY_SECONDS and int(recent.reserve_shots) > 0:
		_state = "reserve"
		_deficit = false
		_entry_checks = 0
		return
	_state = "deficit" if _deficit else "quiet"
	if _buckets.size() < WINDOW_SECONDS:
		_state = "quiet"
		return
	var totals := _totals(WINDOW_SECONDS)
	var recent_recovered := float(recent.spent) <= float(recent.supplied) + EPSILON
	if recent_recovered or float(totals.spent) <= float(totals.supplied) + EPSILON:
		_deficit = false
		_entry_checks = 0
	else:
		var sustained := int(totals.combat_seconds) >= MIN_COMBAT_SECONDS
		var clear_deficit := float(totals.spent) - float(totals.supplied) >= MIN_DEFICIT
		var above_margin := float(totals.spent) >= float(totals.supplied) * ENTRY_RATIO
		if sustained and clear_deficit and above_margin:
			_entry_checks = mini(ENTRY_CHECKS, _entry_checks + 1)
			if _entry_checks >= ENTRY_CHECKS:
				_deficit = true
		else:
			_entry_checks = 0
	_state = "deficit" if _deficit else "quiet"


func _totals(seconds: int) -> Dictionary:
	var result := _empty_bucket()
	result["seconds"] = mini(seconds, _buckets.size())
	result["combat_seconds"] = 0
	for index in range(maxi(0, _buckets.size() - seconds), _buckets.size()):
		var bucket: Dictionary = _buckets[index]
		result.base += float(bucket.base)
		result.factory += float(bucket.factory)
		result.spent += float(bucket.spent)
		result.reserve_shots += int(bucket.reserve_shots)
		if float(bucket.spent) > EPSILON or int(bucket.reserve_shots) > 0:
			result.combat_seconds += 1
	result["supplied"] = float(result.base) + float(result.factory)
	return result


static func _empty_bucket() -> Dictionary:
	return {"base": 0.0, "factory": 0.0, "spent": 0.0, "reserve_shots": 0}


static func _workshop_context(states: Array[String]) -> Dictionary:
	var counts := {}
	for state in states:
		counts[state] = int(counts.get(state, 0)) + 1
	if states.is_empty():
		return {"hint": "工房なし", "counts": counts}
	# One factual current state, never a predicted best upgrade or root cause.
	# Pick the largest stopped group; ties have a stable priority. Count wording
	# deliberately avoids implying that every workshop shares this state.
	var chosen := ""
	var largest := 0
	for state in STOP_PRIORITY:
		var count := int(counts.get(state, 0))
		if count > largest:
			chosen = state
			largest = count
	if largest > 0:
		var title := "廃材不足" if chosen == "資材不足" else chosen
		return {"hint": "%sの工房%d棟" % [title, largest], "counts": counts}
	var producing := int(counts.get("生産中", 0))
	if producing > 0:
		return {"hint": "工房%d棟は生産中" % producing, "counts": counts}
	if int(counts.get("補給満杯", 0)) == states.size():
		return {"hint": "工房は補給満杯", "counts": counts}
	return {"hint": "工房の状態未確認", "counts": counts}
