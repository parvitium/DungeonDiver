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


func facing_yaw() -> float:
	# Default Node3D forward is -Z, which is north in this generator.
	if bool(doors.get("n", false)):
		return 0.0
	if bool(doors.get("e", false)):
		return -PI * 0.5
	if bool(doors.get("s", false)):
		return PI
	if bool(doors.get("w", false)):
		return PI * 0.5
	return 0.0


func to_dict() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"kind": int(kind),
		"doors": doors.duplicate(),
		"monster_ids": Array(monster_ids),
		"has_chest": has_chest,
		"has_exit": has_exit,
	}
