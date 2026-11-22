class_name Shop
extends RefCounted
## Sell, buyback, and rotating town stock. Prices follow rarity plus stats.

const BUYBACK_CAP := 6
const STOCK_SIZE := 6
const RARITY_BASE := [10, 22, 48, 96, 180]


static func sell_price(item: ItemInstance) -> int:
	if item == null:
		return 0
	var rarity_i := clampi(int(item.rarity), 0, RARITY_BASE.size() - 1)
	var stats := item.stats
	var stat_sum := 0.0
	if stats:
		stat_sum = stats.attack + stats.defense + stats.max_health * 0.35 + stats.max_stamina * 0.2 + stats.spell_power
	var ilvl := maxi(1, item.item_level)
	return maxi(1, int(RARITY_BASE[rarity_i] + stat_sum * 0.85 + ilvl * 3))


static func buy_price(item: ItemInstance) -> int:
	return maxi(2, int(sell_price(item) * 2.2))


static func rotate_stock(best_depth: int, seed: int, item_defs: Dictionary) -> Array:
	var defs: Array = item_defs.values()
	if defs.is_empty():
		return []
	var rng := GameRNG.new(maxi(1, seed))
	var stock: Array = []
	var depth := maxi(1, best_depth)
	for _i in STOCK_SIZE:
		var def: ItemDef = defs[rng.randi_range(0, defs.size() - 1)]
		var ilvl := clampi(depth + rng.randi_range(0, 2), 1, 12)
		var item := LootGenerator.make_item(def, ilvl, rng)
		if item == null:
			continue
		if depth >= 3 and rng.randf() < 0.35:
			item.rarity = mini(int(item.rarity) + 1, int(DD.Rarity.LEGENDARY)) as DD.Rarity
			item.stats = def.stats().scaled(DD.rarity_multiplier(item.rarity) * (1.0 + ilvl * 0.08))
		stock.append(item)
	return stock


static func ensure_stock(profile: PlayerProfile, item_defs: Dictionary, seed: int) -> void:
	if profile == null:
		return
	var depth := profile.progression.best_depth()
	if profile.shop_stock.size() >= STOCK_SIZE and profile.shop_depth == depth:
		return
	profile.shop_stock = rotate_stock(depth, seed + depth * 17, item_defs)
	profile.shop_depth = depth


static func sell(profile: PlayerProfile, instance_id: String) -> int:
	if profile == null:
		return 0
	var inv := profile.inventory
	var item := inv.find(instance_id)
	if item == null:
		return 0
	if inv.is_equipped(instance_id):
		inv.unequip(inv.equipped_slot_of(instance_id))
	var removed := inv.remove_item(instance_id)
	if removed == null:
		return 0
	var price := sell_price(removed)
	profile.gold += price
	profile.shop_buyback.push_front(removed)
	while profile.shop_buyback.size() > BUYBACK_CAP:
		profile.shop_buyback.pop_back()
	return price


static func buy(profile: PlayerProfile, item: ItemInstance, price: int) -> bool:
	if profile == null or item == null:
		return false
	if profile.gold < price:
		return false
	profile.gold -= price
	profile.inventory.add_item(item)
	return true


static func buy_from_stock(profile: PlayerProfile, index: int) -> bool:
	if profile == null or index < 0 or index >= profile.shop_stock.size():
		return false
	var item: ItemInstance = profile.shop_stock[index]
	var price := buy_price(item)
	if not buy(profile, item, price):
		return false
	profile.shop_stock.remove_at(index)
	return true


static func buyback(profile: PlayerProfile, index: int) -> bool:
	if profile == null or index < 0 or index >= profile.shop_buyback.size():
		return false
	var item: ItemInstance = profile.shop_buyback[index]
	var price := sell_price(item)
	if not buy(profile, item, price):
		return false
	profile.shop_buyback.remove_at(index)
	return true
