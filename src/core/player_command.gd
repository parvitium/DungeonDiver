class_name PlayerCommand
extends RefCounted
## One tick of intent. Presentation/input fills this; simulation consumes it.
## Future co-op: serialize this and send to the host.

var move: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var jump: bool = false
var sprint: bool = false
var melee: bool = false
var block: bool = false
var cast: bool = false
var interact: bool = false


func to_dict() -> Dictionary:
	return {
		"move": [move.x, move.y],
		"look_delta": [look_delta.x, look_delta.y],
		"jump": jump,
		"sprint": sprint,
		"melee": melee,
		"block": block,
		"cast": cast,
		"interact": interact,
	}


static func from_dict(data: Dictionary) -> PlayerCommand:
	var cmd := PlayerCommand.new()
	var move_arr: Variant = data.get("move", [0.0, 0.0])
	var look_arr: Variant = data.get("look_delta", [0.0, 0.0])
	if move_arr is Array and move_arr.size() >= 2:
		cmd.move = Vector2(float(move_arr[0]), float(move_arr[1]))
	if look_arr is Array and look_arr.size() >= 2:
		cmd.look_delta = Vector2(float(look_arr[0]), float(look_arr[1]))
	cmd.jump = bool(data.get("jump", false))
	cmd.sprint = bool(data.get("sprint", false))
	cmd.melee = bool(data.get("melee", false))
	cmd.block = bool(data.get("block", false))
	cmd.cast = bool(data.get("cast", false))
	cmd.interact = bool(data.get("interact", false))
	return cmd
