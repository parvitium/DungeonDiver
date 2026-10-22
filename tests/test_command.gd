class_name TestCommand
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("command")
	var cmd := PlayerCommand.new()
	cmd.move = Vector2(0.5, -1.0)
	cmd.look_delta = Vector2(3, 4)
	cmd.melee = true
	cmd.sprint = true
	var copy := PlayerCommand.from_dict(cmd.to_dict())
	t.assert_eq(copy.move.x, 0.5, "move x")
	t.assert_eq(copy.move.y, -1.0, "move y")
	t.assert_eq(copy.look_delta.y, 4.0, "look y")
	t.assert_true(copy.melee, "melee")
	t.assert_true(copy.sprint, "sprint")
	t.assert_false(copy.cast, "cast default")
	return t
