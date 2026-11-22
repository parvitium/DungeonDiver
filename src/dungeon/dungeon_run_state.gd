class_name DungeonRunState
extends RefCounted

var dungeon_id: StringName = &""
var depth: int = 1
var effective_tier: int = 1
var seed_value: int = 0
var blueprint: DungeonBlueprint = null
var boss_defeated: bool = false
var living_monsters: int = 0
var kills_this_run: int = 0
var opened_chests: Dictionary = {}
var entry_inventory: Dictionary = {}


func chest_key(pos: Vector3) -> String:
	return "%d_%d_%d" % [int(round(pos.x * 10.0)), int(round(pos.y * 10.0)), int(round(pos.z * 10.0))]


func mark_chest_open(key: String) -> void:
	if key.is_empty():
		return
	opened_chests[key] = true


func is_chest_open(key: String) -> bool:
	return opened_chests.has(key) and bool(opened_chests[key])
