class_name PlayerProfile
extends RefCounted

const BASE_HEALTH := 100.0
const BASE_STAMINA := 100.0
const BASE_ATTACK := 4.0
const BASE_DEFENSE := 2.0
const BASE_SPELL := 4.0

var display_name: String = "Diver"
var inventory: Inventory = Inventory.new()
var progression: ProgressionState = ProgressionState.new()
var current_health: float = BASE_HEALTH
var current_stamina: float = BASE_STAMINA


func base_stats() -> StatBlock:
	return StatBlock.new(BASE_ATTACK, BASE_DEFENSE, BASE_HEALTH, BASE_STAMINA, BASE_SPELL)


func total_stats() -> StatBlock:
	return base_stats().add(inventory.equipped_stats())


func clamp_vitals() -> void:
	var stats := total_stats()
	current_health = clampf(current_health, 0.0, stats.max_health)
	current_stamina = clampf(current_stamina, 0.0, stats.max_stamina)


func refill() -> void:
	var stats := total_stats()
	current_health = stats.max_health
	current_stamina = stats.max_stamina


func grant_starter_kit(item_defs: Dictionary, rng: GameRNG) -> void:
	if not inventory.items.is_empty():
		return
	for slot in inventory.equipped:
		if slot != null:
			return
	if item_defs.has("rusty_sword"):
		var sword := LootGenerator.make_item(item_defs["rusty_sword"], 1, rng)
		sword.rarity = DD.Rarity.COMMON
		sword.stats = item_defs["rusty_sword"].stats().scaled(1.0)
		inventory.add_item(sword)
		inventory.equip(sword.instance_id)
	if item_defs.has("tattered_vest"):
		var vest := LootGenerator.make_item(item_defs["tattered_vest"], 1, rng)
		vest.rarity = DD.Rarity.COMMON
		vest.stats = item_defs["tattered_vest"].stats().scaled(1.0)
		inventory.add_item(vest)
		inventory.equip(vest.instance_id)
	refill()


func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"inventory": inventory.to_dict(),
		"progression": progression.to_dict(),
		"current_health": current_health,
		"current_stamina": current_stamina,
	}


static func from_dict(data: Variant) -> PlayerProfile:
	if not data is Dictionary:
		return null
	var dict: Dictionary = data
	if dict.has("display_name") and not dict["display_name"] is String:
		return null
	if dict.has("current_health") and not DD.is_number(dict["current_health"]):
		return null
	if dict.has("current_stamina") and not DD.is_number(dict["current_stamina"]):
		return null
	if dict.has("inventory") and not dict["inventory"] is Dictionary:
		return null
	if dict.has("progression") and not dict["progression"] is Dictionary:
		return null
	var inventory := Inventory.from_dict(dict.get("inventory", {}))
	if inventory == null:
		return null
	var progression := ProgressionState.from_dict(dict.get("progression", {}))
	if progression == null:
		return null
	var profile := PlayerProfile.new()
	profile.display_name = str(dict.get("display_name", "Diver"))
	profile.inventory = inventory
	profile.progression = progression
	profile.current_health = float(dict.get("current_health", BASE_HEALTH))
	profile.current_stamina = float(dict.get("current_stamina", BASE_STAMINA))
	profile.clamp_vitals()
	return profile
