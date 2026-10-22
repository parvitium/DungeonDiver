class_name LootGenerator
extends RefCounted


static func roll_rarity(rng: GameRNG, effective_tier: int, min_rarity: int = 0, max_rarity: int = 4) -> int:
	var weights := DD.rarity_weights_for_tier(effective_tier)
	for i in weights.size():
		if i < min_rarity or i > max_rarity:
			weights[i] = 0.0
	return clampi(rng.pick_weighted(weights), min_rarity, max_rarity)


static func scale_multiplier(rarity: int, effective_tier: int) -> float:
	return DD.rarity_multiplier(rarity) * DD.depth_scale(effective_tier)


static func make_item(def: ItemDef, effective_tier: int, rng: GameRNG) -> ItemInstance:
	var rarity := roll_rarity(rng, effective_tier, int(def.min_rarity), int(def.max_rarity))
	var item := ItemInstance.new()
	item.instance_id = DD.new_id("item")
	item.def_id = def.id
	item.display_name = def.display_name
	item.slot = def.slot
	item.rarity = rarity as DD.Rarity
	item.item_level = effective_tier
	item.stats = def.stats().scaled(scale_multiplier(rarity, effective_tier))
	return item


static func generate_from_table(table: LootTable, defs: Dictionary, effective_tier: int, rng: GameRNG) -> Array[ItemInstance]:
	var drops: Array[ItemInstance] = []
	if table == null or table.item_ids.is_empty():
		return drops
	var count := rng.randi_range(table.min_drops, table.max_drops)
	for _i in count:
		var item_id := table.pick_item_id(rng)
		if not defs.has(item_id):
			continue
		drops.append(make_item(defs[item_id], effective_tier, rng))
	return drops
