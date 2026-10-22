class_name LootTable
extends Resource

@export var id: StringName = &""
@export var item_ids: PackedStringArray = []
@export var weights: PackedFloat32Array = []
@export var min_drops: int = 1
@export var max_drops: int = 1


func pick_item_id(rng: GameRNG) -> String:
	return rng.pick_weighted_ids(item_ids, weights)


static func is_valid_extra(resource: Variant) -> bool:
	if not resource is LootTable:
		return false
	var table: LootTable = resource
	if String(table.id).is_empty():
		return false
	if table.item_ids.size() != table.weights.size():
		return false
	if table.min_drops < 0 or table.max_drops < table.min_drops:
		return false
	return true
