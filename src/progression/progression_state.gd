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


func drop_unknown_ids(monster_defs: Dictionary, dungeon_defs: Dictionary) -> void:
	var kept_bestiary: Dictionary = {}
	for key in bestiary.keys():
		if monster_defs.has(String(key)):
			kept_bestiary[key] = bestiary[key]
	bestiary = kept_bestiary
	var kept_conquered: Dictionary = {}
	for key in conquered.keys():
		if dungeon_defs.has(String(key)):
			kept_conquered[key] = conquered[key]
	conquered = kept_conquered
	changed.emit()


func to_dict() -> Dictionary:
	return {
		"bestiary": bestiary.duplicate(true),
		"conquered": conquered.duplicate(true),
	}


static func from_dict(data: Variant) -> ProgressionState:
	if data == null:
		return ProgressionState.new()
	if not data is Dictionary:
		return null
	var dict: Dictionary = data
	if dict.has("bestiary") and not dict["bestiary"] is Dictionary:
		return null
	if dict.has("conquered") and not dict["conquered"] is Dictionary:
		return null
	var state := ProgressionState.new()
	var raw_bestiary: Variant = dict.get("bestiary", {})
	if raw_bestiary is Dictionary:
		var bestiary_copy: Dictionary = {}
		for key in raw_bestiary.keys():
			var entry: Variant = raw_bestiary[key]
			if not entry is Dictionary:
				return null
			var entry_dict: Dictionary = entry
			if entry_dict.has("kills") and not DD.is_number(entry_dict["kills"]):
				return null
			if entry_dict.has("first_unix") and not DD.is_number(entry_dict["first_unix"]):
				return null
			bestiary_copy[String(key)] = entry_dict.duplicate(true)
		state.bestiary = bestiary_copy
	var raw_conquered: Variant = dict.get("conquered", {})
	if raw_conquered is Dictionary:
		var conquered_copy: Dictionary = {}
		for key in raw_conquered.keys():
			var depth: Variant = raw_conquered[key]
			if not DD.is_number(depth):
				return null
			conquered_copy[String(key)] = int(depth)
		state.conquered = conquered_copy
	return state
