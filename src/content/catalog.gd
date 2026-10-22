class_name Catalog
extends RefCounted
## Built-in content pack. Extra .tres files in res://data/ can extend this.


static func all_items() -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	items.append(_item(&"rusty_sword", "Rusty Sword", "A starter blade. Better than fists.", DD.EquipSlot.WEAPON, {
		"attack": 6.0
	}))
	items.append(_item(&"bone_club", "Bone Club", "Heavy and unkind.", DD.EquipSlot.WEAPON, {
		"attack": 9.0, "max_stamina": -4.0
	}))
	items.append(_item(&"fang_dagger", "Fang Dagger", "Fast teeth on a stick.", DD.EquipSlot.WEAPON, {
		"attack": 7.0, "max_stamina": 6.0
	}))
	items.append(_item(&"ember_staff", "Ember Staff", "A cracked focus that still sparks.", DD.EquipSlot.WEAPON, {
		"attack": 3.0, "spell_power": 10.0
	}))
	items.append(_item(&"crypt_lantern", "Crypt Lantern", "Keeps the dark a step back.", DD.EquipSlot.OFFHAND, {
		"spell_power": 4.0, "max_health": 8.0
	}))
	items.append(_item(&"hide_buckler", "Hide Buckler", "Better than catching claws with your face.", DD.EquipSlot.OFFHAND, {
		"defense": 5.0
	}))
	items.append(_item(&"leather_cap", "Leather Cap", "Keeps grit out of your eyes.", DD.EquipSlot.HEAD, {
		"defense": 2.0, "max_health": 6.0
	}))
	items.append(_item(&"iron_helm", "Iron Helm", "Rings like a bell when it works.", DD.EquipSlot.HEAD, {
		"defense": 6.0, "max_health": 10.0
	}))
	items.append(_item(&"tattered_vest", "Tattered Vest", "Mostly still a shirt.", DD.EquipSlot.CHEST, {
		"defense": 3.0, "max_health": 12.0
	}))
	items.append(_item(&"bone_mail", "Bone Mail", "Ribs worn on the outside.", DD.EquipSlot.CHEST, {
		"defense": 8.0, "max_health": 18.0
	}))
	items.append(_item(&"wolfhide_coat", "Wolfhide Coat", "Still smells like the cavern.", DD.EquipSlot.CHEST, {
		"defense": 6.0, "max_stamina": 10.0
	}))
	items.append(_item(&"traveler_boots", "Traveler Boots", "Worn in, not worn out.", DD.EquipSlot.LEGS, {
		"max_stamina": 8.0, "defense": 2.0
	}))
	items.append(_item(&"greaves_of_the_crypt", "Crypt Greaves", "Stone-scuffed and stubborn.", DD.EquipSlot.LEGS, {
		"defense": 5.0, "max_health": 8.0
	}))
	items.append(_item(&"wolf_tooth", "Wolf Tooth", "A trophy that still wants blood.", DD.EquipSlot.ACCESSORY, {
		"attack": 3.0, "max_stamina": 4.0
	}))
	items.append(_item(&"crypt_coin", "Crypt Coin", "Cold even in a closed fist.", DD.EquipSlot.ACCESSORY, {
		"spell_power": 5.0, "max_health": 6.0
	}))
	items.append(_item(&"ember_charm", "Ember Charm", "A coal that never quite dies.", DD.EquipSlot.ACCESSORY, {
		"spell_power": 8.0, "attack": 2.0
	}))
	return items


static func all_monsters() -> Array[MonsterDef]:
	var monsters: Array[MonsterDef] = []
	monsters.append(_monster(
		&"skeleton", "Skeleton", "Rattling patrols of the crypt.",
		false, 42.0, 8.0, 3.0, 1.7, 1.15, 9.0, 15.0, false, 0.0,
		&"crypt_drops", 0.75, Color(0.85, 0.84, 0.78), Vector3.ONE
	))
	monsters.append(_monster(
		&"cave_wolf", "Cave Wolf", "Hunts in the dark between stalagmites.",
		false, 34.0, 9.0, 5.2, 1.6, 0.9, 12.0, 18.0, false, 0.0,
		&"cavern_drops", 0.7, Color(0.45, 0.32, 0.22), Vector3.ONE
	))
	monsters.append(_monster(
		&"wraith", "Wraith", "A cold light that throws bolts of night.",
		false, 48.0, 7.0, 2.6, 8.5, 1.6, 11.0, 17.0, true, 16.0,
		&"mixed_drops", 0.8, Color(0.45, 0.75, 0.9), Vector3.ONE
	))
	monsters.append(_monster(
		&"lich", "Crypt Lich", "The reason the crypt still has a king.",
		true, 170.0, 14.0, 2.4, 9.0, 1.35, 14.0, 22.0, true, 15.0,
		&"boss_drops", 1.0, Color(0.55, 0.2, 0.75), Vector3(1.06, 1.06, 1.06)
	))
	monsters.append(_monster(
		&"cave_troll", "Cave Troll", "A walking boulder with opinions.",
		true, 210.0, 16.0, 2.8, 2.4, 1.5, 11.0, 18.0, false, 0.0,
		&"boss_drops", 1.0, Color(0.35, 0.5, 0.32), Vector3(1.18, 1.18, 1.18)
	))
	return monsters


static func all_dungeons() -> Array[DungeonTypeDef]:
	var dungeons: Array[DungeonTypeDef] = []
	var crypt := DungeonTypeDef.new()
	crypt.id = &"crypt"
	crypt.display_name = "Forgotten Crypt"
	crypt.description = "Bone-lined halls and the last court of a lich."
	crypt.base_tier = 1
	crypt.min_rooms = 5
	crypt.max_rooms = 7
	crypt.monster_pool = PackedStringArray(["skeleton", "wraith"])
	crypt.monster_weights = PackedFloat32Array([70.0, 30.0])
	crypt.boss_id = &"lich"
	crypt.loot_table_id = &"crypt_drops"
	crypt.chest_chance = 0.4
	crypt.floor_color = Color(0.18, 0.18, 0.19)
	crypt.wall_color = Color(0.16, 0.16, 0.17)
	crypt.accent_color = Color(0.52, 0.28, 0.72)
	crypt.fog_color = Color(0.05, 0.055, 0.07)
	crypt.light_color = Color(0.58, 0.68, 0.82)
	dungeons.append(crypt)

	var cavern := DungeonTypeDef.new()
	cavern.id = &"cavern"
	cavern.display_name = "Howling Cavern"
	cavern.description = "Wet stone, wolf packs, and something larger."
	cavern.base_tier = 2
	cavern.min_rooms = 6
	cavern.max_rooms = 8
	cavern.monster_pool = PackedStringArray(["cave_wolf", "wraith"])
	cavern.monster_weights = PackedFloat32Array([75.0, 25.0])
	cavern.boss_id = &"cave_troll"
	cavern.loot_table_id = &"cavern_drops"
	cavern.chest_chance = 0.32
	cavern.floor_color = Color(0.20, 0.18, 0.14)
	cavern.wall_color = Color(0.16, 0.15, 0.12)
	cavern.accent_color = Color(0.25, 0.7, 0.65)
	cavern.fog_color = Color(0.05, 0.055, 0.05)
	cavern.light_color = Color(0.55, 0.62, 0.56)
	dungeons.append(cavern)
	return dungeons


static func all_loot_tables() -> Array[LootTable]:
	var tables: Array[LootTable] = []
	tables.append(_table(&"crypt_drops", ["rusty_sword", "bone_club", "leather_cap", "tattered_vest", "crypt_coin", "crypt_lantern", "greaves_of_the_crypt", "iron_helm"], [16, 14, 12, 12, 10, 10, 8, 8], 1, 1))
	tables.append(_table(&"cavern_drops", ["fang_dagger", "hide_buckler", "wolfhide_coat", "traveler_boots", "wolf_tooth", "ember_staff", "leather_cap"], [16, 14, 14, 12, 12, 10, 8], 1, 1))
	tables.append(_table(&"mixed_drops", ["ember_staff", "ember_charm", "crypt_lantern", "wolf_tooth", "traveler_boots"], [22, 20, 20, 20, 18], 1, 1))
	tables.append(_table(&"boss_drops", ["bone_mail", "iron_helm", "ember_charm", "ember_staff", "wolfhide_coat", "greaves_of_the_crypt"], [18, 16, 18, 16, 16, 16], 2, 3))
	tables.append(_table(&"chest_drops", ["rusty_sword", "tattered_vest", "traveler_boots", "leather_cap", "hide_buckler", "crypt_coin", "wolf_tooth"], [14, 14, 14, 14, 14, 15, 15], 1, 2))
	return tables


static func _item(id: StringName, name: String, desc: String, slot: DD.EquipSlot, stats: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.display_name = name
	def.description = desc
	def.slot = slot
	def.base_stats = stats
	return def


static func _monster(
		id: StringName,
		name: String,
		desc: String,
		is_boss: bool,
		hp: float,
		dmg: float,
		speed: float,
		atk_range: float,
		cooldown: float,
		detect: float,
		lose: float,
		ranged: bool,
		proj_speed: float,
		loot: StringName,
		drop: float,
		color: Color,
		scale: Vector3
	) -> MonsterDef:
	var def := MonsterDef.new()
	def.id = id
	def.display_name = name
	def.description = desc
	def.is_boss = is_boss
	def.max_health = hp
	def.damage = dmg
	def.move_speed = speed
	def.attack_range = atk_range
	def.attack_cooldown = cooldown
	def.detect_range = detect
	def.lose_range = lose
	def.uses_ranged = ranged
	def.projectile_speed = proj_speed
	def.loot_table_id = loot
	def.drop_chance = drop
	def.color = color
	def.scale = scale
	return def


static func _table(id: StringName, ids: Array, weights: Array, min_drops: int, max_drops: int) -> LootTable:
	var table := LootTable.new()
	table.id = id
	table.item_ids = PackedStringArray(ids)
	var packed := PackedFloat32Array()
	for w in weights:
		packed.append(float(w))
	table.weights = packed
	table.min_drops = min_drops
	table.max_drops = max_drops
	return table
