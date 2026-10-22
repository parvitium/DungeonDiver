class_name TestLoot
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("loot")
	var rng := GameRNG.new(7)
	var def := ItemDef.new()
	def.id = &"rusty_sword"
	def.display_name = "Rusty Sword"
	def.slot = DD.EquipSlot.WEAPON
	def.base_stats = {"attack": 6.0}

	var item := LootGenerator.make_item(def, 1, rng)
	t.assert_true(item.instance_id != "", "instance id")
	t.assert_eq(String(item.def_id), "rusty_sword", "def id")
	t.assert_gt(item.stats.attack, 0.0, "scaled attack")
	t.assert_in_range(float(item.rarity), 0.0, 4.0, "rarity bounds")

	var deep := LootGenerator.make_item(def, 5, GameRNG.new(7))
	t.assert_gt(deep.stats.attack, item.stats.attack - 0.01, "higher tier not weaker at same seed family")

	var table := LootTable.new()
	table.item_ids = PackedStringArray(["rusty_sword"])
	table.weights = PackedFloat32Array([1.0])
	table.min_drops = 2
	table.max_drops = 2
	var defs := {"rusty_sword": def}
	var drops := LootGenerator.generate_from_table(table, defs, 2, GameRNG.new(3))
	t.assert_eq(drops.size(), 2, "table drop count")
	t.assert_true(drops[0].instance_id != drops[1].instance_id, "unique instances")

	var empty := LootGenerator.generate_from_table(null, defs, 1, rng)
	t.assert_eq(empty.size(), 0, "null table")

	var common_count := 0
	var rare_plus := 0
	for i in 80:
		var rolled := LootGenerator.roll_rarity(GameRNG.new(100 + i), 1)
		if rolled == DD.Rarity.COMMON:
			common_count += 1
		if rolled >= DD.Rarity.RARE:
			rare_plus += 1
	t.assert_gt(float(common_count), 10.0, "tier 1 still drops commons")
	t.assert_true(rare_plus < common_count, "commons dominate low tier")

	var high_rare := 0
	var low_rare := 0
	for i in 80:
		if LootGenerator.roll_rarity(GameRNG.new(200 + i), 5) >= DD.Rarity.RARE:
			high_rare += 1
		if LootGenerator.roll_rarity(GameRNG.new(200 + i), 1) >= DD.Rarity.RARE:
			low_rare += 1
	t.assert_ge(float(high_rare), float(low_rare), "high tier shifts rarity up")
	return t
