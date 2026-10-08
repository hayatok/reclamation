extends RefCounted
## RECLAMATION upgrade definitions, aligned with master.md appendices A-C.
## `all()` contains exactly 24 progression upgrades; repeatable rewards are separate.
## All percentages are additive against the base stat unless an effect says otherwise.
## The caller owns effect application, weapon/context checks and card RNG persistence.

const CATALOG_VERSION := 2
const DRAW_VERSION := 3
const DRAW_RULE := "有効な攻撃強化を最低1枚保証。残りも無作為・重複なし。"
const LEVEL_DRAW_RULE := "Lv.4まで基本のみ / 基本70・上級25・決戦5 / Lv.6・12は上級以上を保証"
const TIER_WEIGHTS := {"basic":70, "advanced":25, "ultimate":5}
const FAMILIES := {
	"lightning":["chain", "power", "storm", "rate"],
	"explosive":["blast", "blast_radius", "cascade", "damage"],
	"mobile":["multi", "supply", "repair", "fortress", "move"],
	"ballistic":["pierce", "salvo", "sweep", "crit", "critpower"]
}

const DEFINITIONS := [
	{"id":"damage", "name":"強装弾", "tier":"basic", "tag":"FIREPOWER", "desc":"全軍の基礎ダメージ +20%\n最大5ランク / 同項目は加算", "color":Color("ffb85e"), "max_rank":5, "requires":[], "weapon_tag":"all", "offensive":true, "effects":{"damage_add":0.20}},
	{"id":"rate", "name":"高速給弾", "tier":"basic", "tag":"FIREPOWER", "desc":"全軍の攻撃速度 +15%\n最大4ランク / 同項目は加算", "color":Color("ffb85e"), "max_rank":4, "requires":[], "weapon_tag":"all", "offensive":true, "effects":{"attack_speed_add":0.15}},
	{"id":"range", "name":"延伸照準", "tier":"basic", "tag":"TACTICS", "desc":"全軍の射程 +10%\n最大3ランク / 同項目は加算", "color":Color("64e6d2"), "max_rank":3, "requires":[], "weapon_tag":"all", "offensive":true, "effects":{"range_add":0.10}},
	{"id":"pierce", "name":"貫通芯", "tier":"basic", "tag":"BALLISTICS", "desc":"実弾・電磁弾の貫通対象 +1\n最大3ランク / 貫通先に再発火なし", "color":Color("ffb85e"), "max_rank":3, "requires":[], "weapon_tag":"ballistic", "offensive":true, "effects":{"pierce_add":1}},
	{"id":"blast_radius", "name":"広域弾頭", "tier":"basic", "tag":"EXPLOSIVES", "desc":"爆発半径 +15%\n誘爆装薬が必要 / 最大3ランク", "color":Color("ffb85e"), "max_rank":3, "requires":["blast"], "weapon_tag":"explosive", "offensive":true, "effects":{"blast_radius_add":0.15}},
	{"id":"crit", "name":"弱点解析", "tier":"basic", "tag":"FIREPOWER", "desc":"通常射撃のクリティカル率 +10pt\n基本倍率1.5倍 / 最大4ランク", "color":Color("ffb85e"), "max_rank":4, "requires":[], "weapon_tag":"primary", "offensive":true, "effects":{"crit_chance_add":0.10}},
	{"id":"armor", "name":"複層装甲", "tier":"basic", "tag":"SURVIVAL", "desc":"全軍の最大耐久 +20%\n増加分を即時回復 / 最大3ランク", "color":Color("64e6d2"), "max_rank":3, "requires":[], "weapon_tag":"none", "offensive":false, "effects":{"max_hp_add":0.20, "heal_hp_increase":true}},
	{"id":"move", "name":"高機動展開", "tier":"basic", "tag":"MOBILITY", "desc":"班と補給車の移動速度 +12%\n最大3ランク / 同項目は加算", "color":Color("64e6d2"), "max_rank":3, "requires":[], "weapon_tag":"none", "offensive":false, "effects":{"move_speed_add":0.12}},
	{"id":"supply", "name":"自動回収給弾", "tier":"basic", "tag":"SUPPLY", "desc":"主射撃の弾薬消費 -15pt\n基礎消費量から減算 / 最大3ランク", "color":Color("64e6d2"), "max_rank":3, "requires":[], "weapon_tag":"primary", "offensive":false, "effects":{"ammo_reduction_add":0.15}},
	{"id":"salvage", "name":"高効率解体", "tier":"basic", "tag":"ECONOMY", "desc":"工兵の資材回収速度 +20%\n最大3ランク / 同項目は加算", "color":Color("64e6d2"), "max_rank":3, "requires":[], "weapon_tag":"none", "offensive":false, "effects":{"salvage_speed_add":0.20}},
	{"id":"build", "name":"組立ライン", "tier":"basic", "tag":"ECONOMY", "desc":"建設・部隊生産速度 +20%\n最大3ランク / 同項目は加算", "color":Color("64e6d2"), "max_rank":3, "requires":[], "weapon_tag":"none", "offensive":false, "effects":{"build_speed_add":0.20, "production_speed_add":0.20}},
	{"id":"power", "name":"高密度蓄電", "tier":"basic", "tag":"POWER", "desc":"発電容量 +15%\n導電跳躍と組み合わせて雷光網へ", "color":Color("95d7ff"), "max_rank":3, "requires":[], "weapon_tag":"none", "offensive":false, "effects":{"power_capacity_add":0.15}},

	{"id":"multi", "name":"分岐斉射", "tier":"advanced", "tag":"ADVANCED / BALLISTICS", "desc":"射撃・砲撃の追加弾 +1\n追加弾は65%威力 / 最大2ランク", "color":Color("d0a0ff"), "max_rank":2, "requires":[], "weapon_tag":"ballistic", "offensive":true, "effects":{"projectiles_add":1, "extra_projectile_multiplier":0.65}},
	{"id":"chain", "name":"導電跳躍", "tier":"advanced", "tag":"ADVANCED / LIGHTNING", "desc":"電撃が追加2体へ連鎖\n跳躍ごとに威力×0.65 / 最大2ランク", "color":Color("95d7ff"), "max_rank":2, "requires":[], "weapon_tag":"primary", "offensive":true, "effects":{"chain_targets_add":2, "chain_falloff":0.65, "grants_electric_attack":true}},
	{"id":"blast", "name":"誘爆装薬", "tier":"advanced", "tag":"ADVANCED / EXPLOSIVES", "desc":"直接撃破で半径2mの爆発\n元の一撃の40%威力 / 第2ランク60%", "color":Color("ffb85e"), "max_rank":2, "requires":[], "weapon_tag":"primary", "offensive":true, "effects":{"blast_radius_base":2.0, "blast_damage_base":0.40, "blast_damage_per_extra_rank":0.20, "direct_kill_only":true}},
	{"id":"critpower", "name":"破砕演算", "tier":"advanced", "tag":"ADVANCED / FIREPOWER", "desc":"クリティカル倍率 +0.25\n弱点解析が必要 / 最大2ランク", "color":Color("d0a0ff"), "max_rank":2, "requires":["crit"], "weapon_tag":"primary", "offensive":true, "effects":{"crit_multiplier_add":0.25}},
	{"id":"overload", "name":"過負荷火力", "tier":"advanced", "tag":"ADVANCED / PRESSURE", "desc":"地域警戒60以上で別枠威力 +15%\n最大2ランク / 警戒低下で解除", "color":Color("d0a0ff"), "max_rank":2, "requires":[], "weapon_tag":"all", "offensive":false, "effects":{"conditional_damage_add":0.15, "noise_threshold":60.0}},
	{"id":"salvo", "name":"同期砲列", "tier":"advanced", "tag":"ADVANCED / SALVO", "desc":"塔・固定迫撃砲・移動迫撃車に無料斉射\n塔は横断100% / 砲は追加2発×60%", "color":Color("d0a0ff"), "max_rank":2, "requires":[], "weapon_tag":"tower", "offensive":true, "effects":{"salvo_shots_rank_1":6, "salvo_shots_rank_2":4, "salvo_damage_multiplier":1.0}},
	{"id":"repair", "name":"戦闘補修", "tier":"advanced", "tag":"ADVANCED / SUPPORT", "desc":"補給圏内の班・塔が毎秒耐久0.5%回復\n被弾中も継続 / 最大2ランク", "color":Color("d0a0ff"), "max_rank":2, "requires":[], "weapon_tag":"none", "offensive":false, "effects":{"regen_max_hp_per_second":0.005, "requires_supply_range":true}},
	{"id":"economy", "name":"勝利の生産線", "tier":"advanced", "tag":"ADVANCED / ECONOMY", "desc":"25撃破ごとに生産速度 +25%・8秒\n第2ランク+50% / 再発動は持続延長", "color":Color("d0a0ff"), "max_rank":2, "requires":[], "weapon_tag":"none", "offensive":false, "effects":{"kills_per_trigger":25, "production_burst_add":0.25, "duration_seconds":8.0, "duration_refresh_only":true}},

	{"id":"storm", "name":"雷光網", "tier":"ultimate", "tag":"ULTIMATE / LIGHTNING", "desc":"連鎖対象 +1 / 帯電柵で4秒電撃被害×1.25\n必要：導電跳躍 + 高密度蓄電", "color":Color("95d7ff"), "max_rank":1, "requires":["chain","power"], "weapon_tag":"electric", "offensive":true, "effects":{"chain_targets_add":1, "electric_vulnerability_multiplier":1.25, "vulnerability_seconds":4.0}},
	{"id":"cascade", "name":"連鎖解体", "tier":"ultimate", "tag":"ULTIMATE / EXPLOSIVES", "desc":"誘爆撃破から第2世代まで再爆発\n次世代威力×0.5 / 必要：誘爆 + 広域弾頭", "color":Color("ffb85e"), "max_rank":1, "requires":["blast","blast_radius"], "weapon_tag":"explosive", "offensive":true, "effects":{"max_explosion_generation":2, "next_generation_multiplier":0.50}},
	{"id":"sweep", "name":"地平線斉射", "tier":"ultimate", "tag":"ULTIMATE / SALVO", "desc":"塔は6体貫通波・横断レーン +1\n迫撃砲は前方への追加砲弾 +2\n必要：同期砲列 + 貫通芯", "color":Color("f0d58d"), "max_rank":1, "requires":["salvo","pierce"], "weapon_tag":"tower", "offensive":true, "effects":{"sweep_target_limit":6, "salvo_lanes_add":1}},
	{"id":"fortress", "name":"歩く工廠", "tier":"ultimate", "tag":"ULTIMATE / SUPPORT", "desc":"移動補給圏：班の威力+20%・弾薬消費-10pt\n必要：自動回収給弾 + 戦闘補修", "color":Color("f0d58d"), "max_rank":1, "requires":["supply","repair"], "weapon_tag":"none", "offensive":false, "effects":{"mobile_supply_range":true, "conditional_damage_add":0.20, "ammo_reduction_add":0.10}}
]

const FALLBACKS := [
	{"id":"reserve", "name":"補給物資", "tier":"fallback", "tag":"SUPPLY", "desc":"資材 +80\n強化候補不足時の即時補給", "color":Color("64e6d2"), "max_rank":-1, "requires":[], "weapon_tag":"none", "offensive":false, "fallback":true, "effects":{"resources_once":80}},
	{"id":"field_repair", "name":"前線補充", "tier":"fallback", "tag":"SURVIVAL", "desc":"全部隊と建造物の耐久を全回復\n強化候補不足時の緊急補修", "color":Color("64e6d2"), "max_rank":-1, "requires":[], "weapon_tag":"none", "offensive":false, "fallback":true, "effects":{"heal_all_once":true}},
	{"id":"reserve2", "name":"工廠の総動員", "tier":"fallback", "tag":"ECONOMY", "desc":"建設・部隊生産速度 +50%・12秒\n同時再発動は持続時間のみ更新", "color":Color("ffb85e"), "max_rank":-1, "requires":[], "weapon_tag":"none", "offensive":false, "fallback":true, "effects":{"build_burst_add":0.50, "production_burst_add":0.50, "duration_seconds":12.0, "duration_refresh_only":true}}
]

static func all() -> Array:
	var result: Array = []
	for card in DEFINITIONS:
		result.append(_copy_card(card))
	return result

static func fallback_defs() -> Array:
	var result: Array = []
	for card in FALLBACKS:
		result.append(_copy_card(card))
	return result

static func family_for(id: String) -> String:
	for family in FAMILIES:
		if id in FAMILIES[family]:
			return family
	return ""

static func _copy_card(card: Dictionary) -> Dictionary:
	var result := card.duplicate(true)
	result["family"] = family_for(card.id)
	return result

## Finds normal or fallback cards, for restoring already-drawn card IDs without RNG.
static func by_id(id: String) -> Dictionary:
	for card in DEFINITIONS:
		if card.id == id:
			return _copy_card(card)
	for card in FALLBACKS:
		if card.id == id:
			return _copy_card(card)
	return {}

## Prerequisites are AND conditions: each listed upgrade must have at least rank one.
## This prototype always has ballistic weapons; blast_radius uses blast as its source.
## Weapon tags are metadata, not a claim that this ranks-only API inspects live units.
static func eligible(ranks: Dictionary) -> Array:
	var result: Array = []
	for card in DEFINITIONS:
		if int(ranks.get(card.id, 0)) >= int(card.max_rank):
			continue
		var allowed := true
		for prerequisite in card.requires:
			if int(ranks.get(prerequisite, 0)) < 1:
				allowed = false
				break
		if allowed:
			result.append(_copy_card(card))
	return result

## Stateful campaign draw. `level` is the newly attained legion level being offered.
## Caller owns family selection/miss accounting, exclusion/reroll state and saving.
## In priority order: offense; an advanced+ card at L6/L12; the selected family after
## three consecutive misses. A card can satisfy multiple reservations. Each of the
## at most three reservations consumes one slot, so no feasible constraint overflows.
## L1-L4 hard-filter to basic cards before every reservation, including family pity.
## Unavailable constraints are skipped, never bypassing prerequisites or rank caps.
static func draw_for_level(ranks: Dictionary, rng: RandomNumberGenerator, level: int, family: String = "", family_misses: int = 0) -> Array:
	var pool := eligible(ranks)
	if level <= 4:
		pool = pool.filter(func(card): return card.tier == "basic")
	var result: Array = []
	var candidates := pool.filter(func(card): return card.offensive)
	_reserve_weighted(result, pool, candidates, rng)
	if level in [6, 12] and not result.any(func(card): return card.tier in ["advanced", "ultimate"]):
		candidates = pool.filter(func(card): return card.tier in ["advanced", "ultimate"])
		_reserve_weighted(result, pool, candidates, rng)
	if family_misses >= 3 and FAMILIES.has(family) and not result.any(func(card): return card.family == family):
		candidates = pool.filter(func(card): return card.family == family)
		_reserve_weighted(result, pool, candidates, rng)
	while result.size() < 3 and not pool.is_empty():
		var card := _pick_weighted(pool, rng)
		result.append(card)
		pool.erase(card)
	var bonuses := fallback_defs()
	while result.size() < 3:
		result.append(bonuses.pop_at(rng.randi_range(0, bonuses.size() - 1)))
	_shuffle_cards(result, rng)
	return result

static func _reserve_weighted(result: Array, pool: Array, candidates: Array, rng: RandomNumberGenerator) -> void:
	if candidates.is_empty() or result.size() >= 3:
		return
	var card := _pick_weighted(candidates, rng)
	result.append(card)
	pool.erase(card)

## Weights apply to eligible tiers, not to individual cards: adding more basics does
## not multiply the basic tier's 70 weight. Guarantees constrain the pool first.
## Therefore forced milestone/family cards intentionally alter the whole-hand ratio.
static func _pick_weighted(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	if pool.is_empty():
		return {}
	var tier_pools := {"basic":[], "advanced":[], "ultimate":[]}
	var total_weight := 0
	for card in pool:
		if tier_pools.has(card.tier):
			tier_pools[card.tier].append(card)
	for tier in TIER_WEIGHTS:
		if not tier_pools[tier].is_empty():
			total_weight += TIER_WEIGHTS[tier]
	if total_weight == 0:
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll := rng.randi_range(1, total_weight)
	for tier in TIER_WEIGHTS:
		if tier_pools[tier].is_empty():
			continue
		roll -= TIER_WEIGHTS[tier]
		if roll <= 0:
			var tier_pool: Array = tier_pools[tier]
			return tier_pool[rng.randi_range(0, tier_pool.size() - 1)]
	return pool.back()

static func _shuffle_cards(cards: Array, rng: RandomNumberGenerator) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temp: Dictionary = cards[index]
		cards[index] = cards[other]
		cards[other] = temp

## Public draw policy: uniformly choose one offensive card when any is eligible;
## fill remaining slots uniformly without replacement, then randomize slot positions.
## No fixed priority, hidden build preference, global RNG or mutation of input ranks.
## Tier weights/level gates/rerolls need campaign state and are not silently simulated.
static func draw_three(ranks: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool := eligible(ranks)
	var result: Array = []
	var attack_indices: Array = []
	for index in range(pool.size()):
		if pool[index].offensive:
			attack_indices.append(index)
	if not attack_indices.is_empty():
		var guaranteed_index: int = attack_indices[rng.randi_range(0, attack_indices.size() - 1)]
		result.append(pool.pop_at(guaranteed_index))
	# Fill only a genuinely short pool, using randomized distinct fallback rewards.
	if pool.size() + result.size() < 3:
		var bonuses := fallback_defs()
		while pool.size() + result.size() < 3:
			pool.append(bonuses.pop_at(rng.randi_range(0, bonuses.size() - 1)))
	while result.size() < 3:
		result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	for index in range(result.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temp: Dictionary = result[index]
		result[index] = result[other]
		result[other] = temp
	return result
