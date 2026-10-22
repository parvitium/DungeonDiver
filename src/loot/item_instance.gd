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


static func from_dict(data: Variant) -> ItemInstance:
	if not data is Dictionary:
		return null
	var dict: Dictionary = data
	if dict.has("instance_id") and not dict["instance_id"] is String:
		return null
	if dict.has("def_id") and not (dict["def_id"] is String or dict["def_id"] is StringName):
		return null
	if dict.has("display_name") and not dict["display_name"] is String:
		return null
	for key in ["slot", "rarity", "item_level"]:
		if dict.has(key) and not DD.is_number(dict[key]):
			return null
	if dict.has("stats") and not dict["stats"] is Dictionary:
		return null
	var stats := StatBlock.from_dict(dict.get("stats", {}))
	if stats == null:
		return null
	var item := ItemInstance.new()
	item.instance_id = str(dict.get("instance_id", DD.new_id("item")))
	item.def_id = StringName(str(dict.get("def_id", "")))
	item.display_name = str(dict.get("display_name", "Unknown Relic"))
	item.slot = clampi(int(dict.get("slot", 0)), 0, Inventory.SLOT_COUNT - 1) as DD.EquipSlot
	item.rarity = clampi(int(dict.get("rarity", 0)), 0, 4) as DD.Rarity
	item.item_level = maxi(1, int(dict.get("item_level", 1)))
	item.stats = stats
	return item
