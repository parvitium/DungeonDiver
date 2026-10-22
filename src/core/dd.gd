class_name DD
extends RefCounted
## Shared enums and scaling tables. Simulation code should depend on this,
## not on nodes or Input.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum EquipSlot { WEAPON, OFFHAND, HEAD, CHEST, LEGS, ACCESSORY }
enum AttackKind { MELEE, SPELL, MONSTER }
enum RoomKind { START, COMBAT, TREASURE, BOSS }

const RARITY_NAMES: PackedStringArray = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const SLOT_NAMES: PackedStringArray = ["Weapon", "Offhand", "Head", "Chest", "Legs", "Accessory"]

const RARITY_MULT: PackedFloat32Array = [1.0, 1.15, 1.35, 1.6, 2.0]

## Weight of each rarity at dungeon effective-tier 1. Higher tiers shift right.
const BASE_RARITY_WEIGHTS: PackedFloat32Array = [55.0, 28.0, 12.0, 4.0, 1.0]

const SAVE_PATH := "user://dungeondiver_save.json"
const SAVE_VERSION := 1

const WORLD_LAYER := 1
const PLAYER_LAYER := 2
const MONSTER_LAYER := 4
const PROJECTILE_LAYER := 8
const INTERACT_LAYER := 16
const HURTBOX_LAYER := 32

const ROOM_SIZE := 14.0
const WALL_THICKNESS := 0.45
const WALL_HEIGHT := 4.65
const DOOR_WIDTH := 2.8
const DOOR_HEIGHT := 3.0


static func is_number(value: Variant) -> bool:
	return value is int or value is float


static func rarity_name(rarity: int) -> String:
	if rarity < 0 or rarity >= RARITY_NAMES.size():
		return "Unknown"
	return RARITY_NAMES[rarity]


static func slot_name(slot: int) -> String:
	if slot < 0 or slot >= SLOT_NAMES.size():
		return "Unknown"
	return SLOT_NAMES[slot]


static func rarity_color(rarity: int) -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.75, 0.75, 0.75)
		Rarity.UNCOMMON:
			return Color(0.35, 0.85, 0.40)
		Rarity.RARE:
			return Color(0.30, 0.55, 1.0)
		Rarity.EPIC:
			return Color(0.70, 0.35, 0.95)
		Rarity.LEGENDARY:
			return Color(1.0, 0.72, 0.15)
		_:
			return Color.WHITE


static func rarity_multiplier(rarity: int) -> float:
	if rarity < 0 or rarity >= RARITY_MULT.size():
		return 1.0
	return RARITY_MULT[rarity]


static func effective_tier(base_tier: int, depth: int) -> int:
	return maxi(1, base_tier + maxi(1, depth) - 1)


static func depth_scale(effective_tier_value: int) -> float:
	return 1.0 + 0.22 * float(maxi(0, effective_tier_value - 1))


static func rarity_weights_for_tier(effective_tier_value: int) -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	var shift := float(maxi(0, effective_tier_value - 1)) * 0.18
	for i in BASE_RARITY_WEIGHTS.size():
		var bias := 1.0 + shift * float(i - 1)
		weights.append(maxf(0.35, BASE_RARITY_WEIGHTS[i] * bias))
	return weights


static func new_id(prefix: String = "id") -> String:
	return "%s_%s" % [prefix, str(Time.get_ticks_usec())]
