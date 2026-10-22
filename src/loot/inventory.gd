class_name Inventory
extends RefCounted

signal changed

const SLOT_COUNT := 6

var items: Array[ItemInstance] = []
var equipped: Array = [null, null, null, null, null, null]


func add_item(item: ItemInstance) -> void:
	if item == null:
		return
	items.append(item)
	changed.emit()


func remove_item(instance_id: String) -> ItemInstance:
	for i in items.size():
		if items[i].instance_id == instance_id:
			var item := items[i]
			items.remove_at(i)
			changed.emit()
			return item
	return null


func find(instance_id: String) -> ItemInstance:
	for item in items:
		if item.instance_id == instance_id:
			return item
	for slot in equipped.size():
		var worn: Variant = equipped[slot]
		if worn != null and worn.instance_id == instance_id:
			return worn
	return null


func equip(instance_id: String) -> bool:
	var item := find(instance_id)
	if item == null:
		return false
	var slot := int(item.slot)
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	var bag_item := remove_item(instance_id)
	if bag_item == null:
		return false
	var current: Variant = equipped[slot]
	if current != null:
		items.append(current)
	equipped[slot] = bag_item
	changed.emit()
	return true


func unequip(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	var current: Variant = equipped[slot]
	if current == null:
		return false
	equipped[slot] = null
	items.append(current)
	changed.emit()
	return true


func equipped_stats() -> StatBlock:
	var total := StatBlock.new()
	for slot in equipped.size():
		var item: Variant = equipped[slot]
		if item != null:
			total = total.add(item.stats)
	return total


func all_known_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for item in items:
		ids.append(String(item.def_id))
	for slot in equipped.size():
		var item: Variant = equipped[slot]
		if item != null:
			ids.append(String(item.def_id))
	return ids


func to_dict() -> Dictionary:
	var bag: Array = []
	for item in items:
		bag.append(item.to_dict())
	var wear: Array = []
	for slot in equipped.size():
		var item: Variant = equipped[slot]
		wear.append(item.to_dict() if item != null else null)
	return {"items": bag, "equipped": wear}


func drop_unknown_items(item_defs: Dictionary) -> void:
	var kept: Array[ItemInstance] = []
	for item in items:
		if item != null and item_defs.has(String(item.def_id)):
			kept.append(item)
	items = kept
	for i in equipped.size():
		var worn: Variant = equipped[i]
		if worn != null and not item_defs.has(String(worn.def_id)):
			equipped[i] = null
	changed.emit()


static func from_dict(data: Variant) -> Inventory:
	if data == null:
		return Inventory.new()
	if not data is Dictionary:
		return null
	var dict: Dictionary = data
	if dict.has("items") and not dict["items"] is Array:
		return null
	if dict.has("equipped") and not dict["equipped"] is Array:
		return null
	var inv := Inventory.new()
	var bag: Variant = dict.get("items", [])
	if not bag is Array:
		return null
	for entry in bag:
		if not entry is Dictionary:
			return null
		var item := ItemInstance.from_dict(entry)
		if item == null:
			return null
		inv.items.append(item)
	var wear: Variant = dict.get("equipped", [])
	if not wear is Array:
		return null
	for i in mini(SLOT_COUNT, wear.size()):
		if wear[i] == null:
			continue
		if not wear[i] is Dictionary:
			return null
		var worn := ItemInstance.from_dict(wear[i])
		if worn == null:
			return null
		inv.equipped[i] = worn
	return inv
