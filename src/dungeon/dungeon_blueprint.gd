class_name DungeonBlueprint
extends RefCounted

var dungeon_id: StringName = &""
var depth: int = 1
var effective_tier: int = 1
var seed_value: int = 0
var rooms: Array[RoomSpec] = []
var start_cell: Vector2i = Vector2i.ZERO
var boss_cell: Vector2i = Vector2i.ZERO


func room_at(cell: Vector2i) -> RoomSpec:
	for room in rooms:
		if room.cell == cell:
			return room
	return null


func start_room() -> RoomSpec:
	return room_at(start_cell)


func layout_is_connected() -> bool:
	if rooms.is_empty():
		return false
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [start_cell]
	seen[start_cell] = true
	var dirs := {
		"n": Vector2i(0, -1),
		"s": Vector2i(0, 1),
		"e": Vector2i(1, 0),
		"w": Vector2i(-1, 0),
	}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var room := room_at(cell)
		if room == null:
			continue
		for key in dirs.keys():
			if not bool(room.doors.get(key, false)):
				continue
			var next: Vector2i = cell + dirs[key]
			if seen.has(next):
				continue
			if room_at(next) == null:
				continue
			seen[next] = true
			queue.append(next)
	return seen.size() == rooms.size()


func has_boss_and_exit() -> bool:
	var boss := room_at(boss_cell)
	return boss != null and boss.kind == DD.RoomKind.BOSS and boss.has_exit


func to_dict() -> Dictionary:
	var packed: Array = []
	for room in rooms:
		packed.append(room.to_dict())
	return {
		"dungeon_id": String(dungeon_id),
		"depth": depth,
		"effective_tier": effective_tier,
		"seed_value": seed_value,
		"start_cell": [start_cell.x, start_cell.y],
		"boss_cell": [boss_cell.x, boss_cell.y],
		"rooms": packed,
	}
