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
	return StatBlock.from_dict(base_stats)
