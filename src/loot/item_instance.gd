class_name ItemInstance
extends RefCounted

var instance_id: String = ""
var def_id: StringName = &""
var display_name: String = ""
var slot: DD.EquipSlot = DD.EquipSlot.WEAPON
var rarity: DD.Rarity = DD.Rarity.COMMON
var item_level: int = 1
var stats: StatBlock = StatBlock.new()


func full_name() -> String:
	return "%s %s" % [DD.rarity_name(rarity), display_name]


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"def_id": String(def_id),
		"display_name": display_name,
		"slot": int(slot),
		"rarity": int(rarity),
		"item_level": item_level,
		"stats": stats.to_dict(),
	}


static func from_dict(data: Dictionary) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = str(data.get("instance_id", DD.new_id("item")))
	item.def_id = StringName(str(data.get("def_id", "")))
	item.display_name = str(data.get("display_name", "Unknown Relic"))
	item.slot = int(data.get("slot", 0)) as DD.EquipSlot
	item.rarity = int(data.get("rarity", 0)) as DD.Rarity
	item.item_level = int(data.get("item_level", 1))
	item.stats = StatBlock.from_dict(data.get("stats", {}))
	return item
