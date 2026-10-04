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

func validate_hand(cards: Array) -> void:
	check(cards.size() == 3, "Every level-aware hand has exactly three cards")
	var seen: Dictionary = {}
	for card in cards:
		check(not seen.has(card.id), "No repeated card ID in level-aware draw")
		seen[card.id] = true

func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 491034
	var maxed: Dictionary = {}
	var unlocked := {"blast":1,"blast_radius":1,"chain":1,"power":1,"salvo":1,"pierce":1,"supply":1,"repair":1,"crit":1}
	for card in Catalog.all():
		maxed[card.id] = card.max_rank
		check(card.family == Catalog.family_for(card.id), "Family metadata matches lookup")
	check(Catalog.family_for("chain") == "lightning", "Lightning family mapping")
	check(Catalog.family_for("damage") == "explosive", "Explosive family mapping")
	check(Catalog.family_for("multi") == "mobile", "Mobile family mapping")
	check(Catalog.family_for("salvo") == "ballistic", "Ballistic family mapping")
	check(Catalog.family_for("armor") == "", "General support has no forced family")
	check(Catalog.family_for("unknown") == "", "Unknown ID has no family")
	for level in [1, 2, 3, 4]:
		for iteration in 120:
			var hand := Catalog.draw_for_level(unlocked, rng, level, "explosive", 3)
			validate_hand(hand)
			check(hand.all(func(card): return card.tier == "basic"), "Level <=4 never bypasses basic gate for family guarantee")
			check(hand.any(func(card): return card.offensive), "Early levels retain offensive guarantee")
	for level in [5, 6, 7, 12, 18]:
		for family in Catalog.FAMILIES:
			for iteration in 150:
				var hand := Catalog.draw_for_level(unlocked, rng, level, family, 3)
				validate_hand(hand)
				check(hand.any(func(card): return card.offensive), "Level draw guarantees offense")
				check(hand.any(func(card): return card.family == family), "Three misses guarantee an eligible chosen-family option")
				if level in [6, 12]:
					check(hand.any(func(card): return card.tier in ["advanced", "ultimate"]), "L6/L12 guarantee advanced-or-ultimate")
	# Distinct requirements fill three slots exactly, without dropping offense.
	var disjoint := maxed.duplicate(true)
	disjoint["damage"] = 0
	disjoint["overload"] = 0
	disjoint["power"] = 0
	for iteration in 60:
		var hand := Catalog.draw_for_level(disjoint, rng, 6, "lightning", 3)
		validate_hand(hand)
		check(ids(hand).has("damage") and ids(hand).has("overload") and ids(hand).has("power"), "Three disjoint guarantees all survive")
	# Repeatedly forced but exhausted/unknown families degrade to normal valid draws.
	for family in ["lightning", "unknown"]:
		for iteration in 30:
			var hand := Catalog.draw_for_level(maxed, rng, 12, family, 99)
			validate_hand(hand)
			check(hand.all(func(card): return card.get("fallback", false)), "Exhausted pool returns distinct fallback rewards")
	var capped_basics := maxed.duplicate(true)
	capped_basics["chain"] = 0
	var early := Catalog.draw_for_level(capped_basics, rng, 4, "lightning", 3)
	check(early.all(func(card): return card.get("fallback", false)), "Exhausted basics cannot leak unlocked advanced cards before L5")
	var late := Catalog.draw_for_level(capped_basics, rng, 6, "lightning", 3)
	check(ids(late).has("chain"), "One card can satisfy all three guarantees")
	check(late.filter(func(card): return card.get("fallback", false)).size() == 2, "Small level-aware pool fills only missing slots")
	# Family pity does not activate before the third miss.
	var found_without_family := false
	for iteration in 100:
		var hand := Catalog.draw_for_level({}, rng, 5, "mobile", 2)
		if not hand.any(func(card): return card.family == "mobile"):
			found_without_family = true
	check(found_without_family, "Two misses do not prematurely force a family")
	# Test the tier sampler directly: 12 basics still share 70%, rather than 12*70.
	var weights := {"basic":0, "advanced":0, "ultimate":0}
	var definitions := Catalog.all()
	for iteration in 20000:
		weights[Catalog._pick_weighted(definitions, rng).tier] += 1
	for tier in weights:
		var observed := float(weights[tier]) / 20000.0
		var expected := float(Catalog.TIER_WEIGHTS[tier]) / 100.0
		check(absf(observed - expected) < 0.015, "Eligible tier weight is normalized: " + tier)
	# Ineligible tiers redistribute probability among those that remain.
	var advanced_only := definitions.filter(func(card): return card.tier == "advanced")
	for iteration in 50:
		check(Catalog._pick_weighted(advanced_only, rng).tier == "advanced", "Missing tiers renormalize rather than producing empty cards")
	# Save/load can resume this API using only the persisted dedicated RNG state.
	var restored := RandomNumberGenerator.new()
	restored.state = rng.state
	for iteration in 200:
		var before := unlocked.duplicate(true)
		check(ids(Catalog.draw_for_level(unlocked, rng, 12, "ballistic", 4)) == ids(Catalog.draw_for_level(unlocked, restored, 12, "ballistic", 4)), "Restored RNG reproduces level/family draw")
		check(unlocked == before, "Level/family draw does not mutate rank state")
		check(rng.state == restored.state, "Restored RNG advances identically")
	if failures.is_empty():
		print("UPGRADE_DRAW_RULES_PASS: early gate, 70/25/5 tiers, offense, L6/L12, four families, overlap/exhaustion, saved RNG; sampled weights=", weights)
		quit(0)
	else:
		print("UPGRADE_DRAW_RULES_FAIL: ", failures.size())
		quit(1)
