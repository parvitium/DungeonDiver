class_name Inventory
extends RefCounted

signal changed

const SLOT_COUNT := 7

var items: Array[ItemInstance] = []
var equipped: Array = [null, null, null, null, null, null, null]


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


func can_wear_in(item: ItemInstance, slot: int) -> bool:
	if item == null or item.is_consumable:
		return false
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if int(item.slot) == slot:
		return true
	if int(item.slot) == int(DD.EquipSlot.ACCESSORY) and slot == int(DD.EquipSlot.RING):
		return true
	if int(item.slot) == int(DD.EquipSlot.RING) and slot == int(DD.EquipSlot.ACCESSORY):
		return true
	return false


func preferred_slot(item: ItemInstance) -> int:
	if item == null:
		return -1
	var candidates: Array[int] = []
	if int(item.slot) == int(DD.EquipSlot.ACCESSORY) or int(item.slot) == int(DD.EquipSlot.RING):
		candidates.append(int(DD.EquipSlot.ACCESSORY))
		candidates.append(int(DD.EquipSlot.RING))
	else:
		candidates.append(int(item.slot))
	for slot in candidates:
		if equipped[slot] == null and can_wear_in(item, slot):
			return slot
	for slot in candidates:
		if can_wear_in(item, slot):
			return slot
	return -1


func equip(instance_id: String) -> bool:
	return equip_to(instance_id, -1)


func equip_to(instance_id: String, slot: int) -> bool:
	var item := find(instance_id)
	if item == null or item.is_consumable:
		return false
	var dest := slot if slot >= 0 else preferred_slot(item)
	if not can_wear_in(item, dest):
		return false
	var bag_item := remove_item(instance_id)
	if bag_item == null:
		return false
	var current: Variant = equipped[dest]
	if current != null:
		items.append(current)
	equipped[dest] = bag_item
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


func is_equipped(instance_id: String) -> bool:
	for slot in equipped.size():
		var worn: Variant = equipped[slot]
		if worn != null and worn.instance_id == instance_id:
			return true
	return false


func equipped_slot_of(instance_id: String) -> int:
	for slot in equipped.size():
		var worn: Variant = equipped[slot]
		if worn != null and worn.instance_id == instance_id:
			return slot
	return -1


func discard(instance_id: String) -> bool:
	if remove_item(instance_id) != null:
		return true
	var slot := equipped_slot_of(instance_id)
	if slot < 0:
		return false
	equipped[slot] = null
	changed.emit()
	return true


func use_consumable(instance_id: String, profile: PlayerProfile) -> bool:
	var item := find(instance_id)
	if item == null or not item.is_consumable:
		return false
	if item.heal_amount > 0.0 and profile != null:
		var cap := profile.total_stats().max_health
		profile.current_health = minf(cap, profile.current_health + item.heal_amount)
	remove_item(instance_id)
	changed.emit()
	return true


func equipped_stats() -> StatBlock:
	var total := StatBlock.new()
	for slot in equipped.size():
		var item: Variant = equipped[slot]
		if item != null:
			total = total.add(item.stats)
	return total


func compare_delta(item: ItemInstance) -> StatBlock:
	if item == null:
		return StatBlock.new()
	var dest := preferred_slot(item)
	var worn: Variant = equipped[dest] if dest >= 0 else null
	var next := item.stats
	var prev := StatBlock.new()
	if worn != null:
		prev = worn.stats
	return StatBlock.new(
		next.attack - prev.attack,
		next.defense - prev.defense,
		next.max_health - prev.max_health,
		next.max_stamina - prev.max_stamina,
		next.spell_power - prev.spell_power
	)


func instance_ids() -> Dictionary:
	var ids := {}
	for item in items:
		if item != null:
			ids[item.instance_id] = true
	for slot in equipped.size():
		var worn: Variant = equipped[slot]
		if worn != null:
			ids[worn.instance_id] = true
	return ids


static func count_new_instances(before: Inventory, after: Inventory) -> int:
	if before == null or after == null:
		return 0
	var known := before.instance_ids()
	var lost := 0
	for id in after.instance_ids():
		if not known.has(id):
			lost += 1
	return lost


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
