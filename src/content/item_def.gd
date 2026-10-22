class_name ItemDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var slot: DD.EquipSlot = DD.EquipSlot.WEAPON
@export var base_stats: Dictionary = {}
@export var min_rarity: DD.Rarity = DD.Rarity.COMMON
@export var max_rarity: DD.Rarity = DD.Rarity.LEGENDARY


func stats() -> StatBlock:
	var block := StatBlock.from_dict(base_stats)
	return block if block != null else StatBlock.new()


static func is_valid_extra(resource: Variant) -> bool:
	if not resource is ItemDef:
		return false
	var def: ItemDef = resource
	if String(def.id).is_empty() or def.display_name.is_empty():
		return false
	if int(def.slot) < 0 or int(def.slot) >= Inventory.SLOT_COUNT:
		return false
	if int(def.min_rarity) < 0 or int(def.max_rarity) > 4:
		return false
	if int(def.min_rarity) > int(def.max_rarity):
		return false
	if not def.base_stats is Dictionary:
		return false
	for value in def.base_stats.values():
		if not DD.is_number(value):
			return false
	return true
