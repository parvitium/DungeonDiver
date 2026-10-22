class_name LootTable
extends Resource

@export var id: StringName = &""
@export var item_ids: PackedStringArray = []
@export var weights: PackedFloat32Array = []
@export var min_drops: int = 1
@export var max_drops: int = 1


func pick_item_id(rng: GameRNG) -> String:
	return rng.pick_weighted_ids(item_ids, weights)
