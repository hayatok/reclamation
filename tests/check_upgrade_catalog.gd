extends SceneTree

const Catalog = preload("res://upgrade_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func ids(cards: Array) -> Array:
	return cards.map(func(card): return card.id)

func run() -> void:
	var cards := Catalog.all()
	check(cards.size() == 24, "Exactly 24 progression upgrades")
	var tiers := {"basic":0, "advanced":0, "ultimate":0}
	var unique: Dictionary = {}
	var maxed: Dictionary = {}
	for card in cards:
		for field in ["id", "name", "tier", "tag", "desc", "color", "max_rank", "requires", "weapon_tag", "offensive", "effects"]:
			check(card.has(field), "%s has %s" % [card.id, field])
		check(not unique.has(card.id), "Unique progression ID: " + card.id)
		unique[card.id] = true
		maxed[card.id] = card.max_rank
		tiers[card.tier] += 1
		check(card.max_rank > 0, "Positive finite progression max rank")
		check(Catalog.by_id(card.id) == card, "ID lookup preserves full definition")
	check(tiers == {"basic":12, "advanced":8, "ultimate":4}, "Master tier distribution 12 / 8 / 4")
	for card in cards:
		for prerequisite in card.requires:
			check(unique.has(prerequisite), "Known prerequisite " + prerequisite)
	check(Catalog.by_id("damage").effects.damage_add == 0.20, "Damage magnitude +20%")
	check(Catalog.by_id("rate").effects.attack_speed_add == 0.15, "Fire-rate magnitude +15%")
	check(Catalog.by_id("range").effects.range_add == 0.10, "Range magnitude +10%")
	check(Catalog.by_id("armor").effects.max_hp_add == 0.20, "Armor magnitude +20%")
	check(Catalog.by_id("salvage").effects.salvage_speed_add == 0.20, "Salvage magnitude +20%")
	check(Catalog.eligible(maxed).is_empty(), "Maxed upgrades cannot be offered")
	var empty_ids := ids(Catalog.eligible({}))
	for locked in ["blast_radius", "critpower", "storm", "cascade", "sweep", "fortress"]:
		check(not empty_ids.has(locked), "Unmet prerequisite excluded: " + locked)
	for pair in [["storm","chain","power"], ["cascade","blast","blast_radius"], ["sweep","salvo","pierce"], ["fortress","supply","repair"]]:
		check(not ids(Catalog.eligible({pair[1]:1})).has(pair[0]), "First prerequisite alone insufficient: " + pair[0])
		check(not ids(Catalog.eligible({pair[2]:1})).has(pair[0]), "Second prerequisite alone insufficient: " + pair[0])
		check(ids(Catalog.eligible({pair[1]:1,pair[2]:1})).has(pair[0]), "Both prerequisites unlock: " + pair[0])
	# Returned records and nested arrays/dictionaries are defensive copies.
	cards[0].name = "mutated"
	cards[0].effects.damage_add = 999
	cards[20].requires.clear()
	check(Catalog.by_id("damage").name == "強装弾", "Caller cannot mutate catalog name")
	check(Catalog.by_id("damage").effects.damage_add == 0.20, "Caller cannot mutate nested effects")
	check(Catalog.by_id("storm").requires.size() == 2, "Caller cannot mutate nested prerequisites")
	check(Catalog.by_id("unknown").is_empty(), "Unknown ID rejected")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 89342
	b.seed = 89342
	var observed: Dictionary = {}
	var first_slot: Dictionary = {}
	for iteration in 2000:
		var ranks := {} if iteration % 2 == 0 else {"blast":1,"chain":1,"power":1,"pierce":1,"salvo":1,"crit":1}
		var before := ranks.duplicate(true)
		var draw := Catalog.draw_three(ranks, a)
		check(ids(draw) == ids(Catalog.draw_three(ranks, b)), "Same RNG state restores exact draw")
		check(a.state == b.state, "Same draws consume same RNG state")
		check(ranks == before, "Drawing does not mutate input ranks")
		check(draw.size() == 3, "Three offered cards")
		var seen: Dictionary = {}
		var offensive := false
		for card in draw:
			check(not seen.has(card.id), "No duplicate drawn ID")
			check(ids(Catalog.eligible(ranks)).has(card.id), "Drawn upgrade is eligible")
			seen[card.id] = true
			observed[card.id] = true
			offensive = offensive or card.offensive
		check(offensive, "At least one offensive card when available")
		first_slot[draw[0].id] = true
	check(observed.has("chain") and observed.has("blast") and observed.has("salvo"), "All three attack builds appear")
	check(first_slot.size() > 12, "Slot order is randomized without fixed priority")
	for remaining in range(3):
		var ranks := maxed.duplicate(true)
		for index in range(remaining):
			ranks[Catalog.all()[index].id] -= 1
		for iteration in 25:
			var draw := Catalog.draw_three(ranks, a)
			check(draw.size() == 3, "Fallback pool always supplies three cards")
			var seen: Dictionary = {}
			var fallback_count := 0
			for card in draw:
				check(not seen.has(card.id), "Fallback draw has no duplicate IDs")
				seen[card.id] = true
				if card.get("fallback", false):
					fallback_count += 1
					check(Catalog.by_id(card.id) == card, "Fallback IDs restore without redraw")
			check(fallback_count == 3 - remaining, "Fallback only fills missing slots")
	var support_only := maxed.duplicate(true)
	support_only["armor"] = 0
	support_only["move"] = 0
	support_only["salvage"] = 0
	check(ids(Catalog.draw_three(support_only, a)).size() == 3, "All-passive pool remains valid")
	if failures.is_empty():
		print("UPGRADE_CATALOG_PASS: 24 definitions, 12/8/4 tiers, prerequisites, caps, 2,000 seeded draws, offensive guarantee, fallback/save IDs")
		quit(0)
	else:
		print("UPGRADE_CATALOG_FAIL: ", failures.size())
		quit(1)
