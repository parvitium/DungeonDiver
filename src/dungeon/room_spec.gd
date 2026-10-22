class_name RoomSpec
extends RefCounted

var cell: Vector2i = Vector2i.ZERO
var kind: DD.RoomKind = DD.RoomKind.COMBAT
var doors: Dictionary = {"n": false, "s": false, "e": false, "w": false}
var monster_ids: PackedStringArray = []
var has_chest: bool = false
var has_exit: bool = false


func world_origin() -> Vector3:
	return Vector3(float(cell.x) * DD.ROOM_SIZE, 0.0, float(cell.y) * DD.ROOM_SIZE)


func world_center() -> Vector3:
	return world_origin() + Vector3(0.0, 0.0, 0.0)


func entrance_key() -> String:
	for key in ["n", "e", "s", "w"]:
		if bool(doors.get(key, false)):
			return key
	return "n"


func facing_yaw() -> float:
	# Stand just inside the entrance and look into the room, not at the wall.
	match entrance_key():
		"n":
			return PI
		"e":
			return PI * 0.5
		"s":
			return 0.0
		"w":
			return -PI * 0.5
		_:
			return 0.0


func spawn_offset() -> Vector3:
	var inset := DD.ROOM_SIZE * 0.5 - 2.55
	match entrance_key():
		"n":
			return Vector3(0.0, 0.05, -inset)
		"e":
			return Vector3(inset, 0.05, 0.0)
		"s":
			return Vector3(0.0, 0.05, inset)
		"w":
			return Vector3(-inset, 0.05, 0.0)
		_:
			return Vector3(0.0, 0.05, 0.0)


func wall_height() -> float:
	match kind:
		DD.RoomKind.START:
			return 3.55
		DD.RoomKind.TREASURE:
			return 3.9
		DD.RoomKind.BOSS:
			return 5.35
		_:
			return DD.WALL_HEIGHT


func to_dict() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"kind": int(kind),
		"doors": doors.duplicate(),
		"monster_ids": Array(monster_ids),
		"has_chest": has_chest,
		"has_exit": has_exit,
	}
