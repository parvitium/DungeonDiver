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

	_inbox(t)
	_determinism(t)
	return t


static func _inbox(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	session.start_run(&"crypt", 1, 42)
	var first := PlayerCommand.new()
	first.melee = true
	session.submit_command(first)
	t.assert_eq(session.pending_command_count(), 1, "inbox holds command")
	session.tick(0.016)
	t.assert_eq(session.pending_command_count(), 0, "tick drains inbox")
	session.end_run(false)
	DDTest.autoload("SaveService").clear_save()


static func _determinism(t: DDTest) -> void:
	var cmds: Array[PlayerCommand] = []
	var walk := PlayerCommand.new()
	walk.move = Vector2(0, -1)
	walk.sprint = true
	cmds.append(walk)
	var swing := PlayerCommand.new()
	swing.melee = true
	cmds.append(swing)
	var first := _replay(4242, cmds)
	var second := _replay(4242, cmds)
	t.assert_eq(first, second, "same seed + commands => same rolls")
	var other := _replay(4243, cmds)
	t.assert_true(first != other, "different seed changes rolls")
	t.assert_true(DDTest.autoload("GameSession").engine_rng() is RandomNumberGenerator, "session owns RNG")


static func _replay(seed_value: int, cmds: Array[PlayerCommand]) -> String:
	var session := DDTest.autoload("GameSession")
	session.start_run(&"crypt", 1, seed_value)
	for cmd in cmds:
		session.submit_command(cmd)
		session.tick(0.016)
	var parts: PackedStringArray = []
	var loot: Array = session.roll_table(&"crypt_drops")
	for item in loot:
		parts.append("%s:%d:%.2f:%.2f" % [
			String(item.def_id),
			int(item.rarity),
			item.stats.attack,
			item.stats.defense,
		])
	parts.append("drop=%.6f" % session.randf())
	parts.append("combat=%.2f" % CombatResolver.player_melee_power(session.profile.total_stats()))
	session.end_run(false)
	DDTest.autoload("SaveService").clear_save()
	return "|".join(parts)
