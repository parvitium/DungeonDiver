class_name ProgressionState
extends RefCounted
## Bestiary + dungeon conquest log. The long-term "defeat everything" tracker.

signal changed

var bestiary: Dictionary = {}
var conquered: Dictionary = {}


func record_kill(monster_id: StringName) -> void:
	var key := String(monster_id)
	if key.is_empty():
		return
	if not bestiary.has(key):
		bestiary[key] = {"kills": 0, "first_unix": int(Time.get_unix_time_from_system())}
	bestiary[key]["kills"] = int(bestiary[key].get("kills", 0)) + 1
	changed.emit()


func kills_of(monster_id: StringName) -> int:
	var entry: Variant = bestiary.get(String(monster_id), {})
	if entry is Dictionary:
		return int(entry.get("kills", 0))
	return 0


func discovered(monster_id: StringName) -> bool:
	return kills_of(monster_id) > 0


func record_clear(dungeon_id: StringName, depth: int) -> void:
	var key := String(dungeon_id)
	var prev := int(conquered.get(key, 0))
	conquered[key] = maxi(prev, depth)
	changed.emit()


func highest_clear(dungeon_id: StringName) -> int:
	return int(conquered.get(String(dungeon_id), 0))


func dungeon_conquered(dungeon_id: StringName) -> bool:
	return highest_clear(dungeon_id) > 0


func discovered_count(known_monster_ids: PackedStringArray) -> int:
	var count := 0
	for monster_id in known_monster_ids:
		if discovered(StringName(monster_id)):
			count += 1
	return count


func conquered_count(known_dungeon_ids: PackedStringArray) -> int:
	var count := 0
	for dungeon_id in known_dungeon_ids:
		if dungeon_conquered(StringName(dungeon_id)):
			count += 1
	return count


func to_dict() -> Dictionary:
	return {
		"bestiary": bestiary.duplicate(true),
		"conquered": conquered.duplicate(true),
	}


static func from_dict(data: Dictionary) -> ProgressionState:
	var state := ProgressionState.new()
	var raw_bestiary: Variant = data.get("bestiary", {})
	if raw_bestiary is Dictionary:
		state.bestiary = raw_bestiary.duplicate(true)
	var raw_conquered: Variant = data.get("conquered", {})
	if raw_conquered is Dictionary:
		state.conquered = raw_conquered.duplicate(true)
	return state
