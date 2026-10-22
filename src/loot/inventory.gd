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


static func from_dict(data: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for entry in data.get("items", []):
		if entry is Dictionary:
			inv.items.append(ItemInstance.from_dict(entry))
	var wear: Array = data.get("equipped", [])
	for i in mini(SLOT_COUNT, wear.size()):
		if wear[i] is Dictionary:
			inv.equipped[i] = ItemInstance.from_dict(wear[i])
	return inv
