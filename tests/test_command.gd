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
	_ai_stream_separate(t)
	_full_run_with_ai(t)
	return t


static func _inbox(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	t.assert_eq(session.process_physics_priority, 20, "session physics after pawns")
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
	var fingerprint := _loot_fingerprint(session)
	session.end_run(false)
	DDTest.autoload("SaveService").clear_save()
	return fingerprint


static func _loot_fingerprint(session: Node) -> String:
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
	return "|".join(parts)


static func _ai_stream_separate(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	session.start_run(&"crypt", 1, 9001)
	var loot_only := _loot_fingerprint(session)
	session.end_run(false)
	DDTest.autoload("SaveService").clear_save()

	session.start_run(&"crypt", 1, 9001)
	session.ai_rng.randf_range(-3.5, 3.5)
	session.ai_rng.randf_range(-3.5, 3.5)
	var loot_after_ai := _loot_fingerprint(session)
	t.assert_eq(loot_only, loot_after_ai, "AI rolls do not change loot stream")
	t.assert_true(session.engine_ai_rng() is RandomNumberGenerator, "session owns AI RNG")
	t.assert_true(session.engine_rng() != session.engine_ai_rng(), "loot and AI are distinct engines")
	session.end_run(false)
	DDTest.autoload("SaveService").clear_save()


static func _full_run_with_ai(t: DDTest) -> void:
	var cmds: Array[PlayerCommand] = []
	var walk := PlayerCommand.new()
	walk.move = Vector2(0, -1)
	walk.sprint = true
	cmds.append(walk)
	var swing := PlayerCommand.new()
	swing.melee = true
	cmds.append(swing)
	var first := _replay_with_ai(7777, cmds)
	var second := _replay_with_ai(7777, cmds)
	t.assert_eq(first, second, "same seed + commands + AI ticks => same run")
	var other := _replay_with_ai(7778, cmds)
	t.assert_true(first != other, "different seed changes AI run")
	t.assert_true(first.contains("patrol="), "fingerprint includes patrol")
	t.assert_true(first.contains("loot="), "fingerprint includes loot")


static func _replay_with_ai(seed_value: int, cmds: Array[PlayerCommand]) -> String:
	var session := DDTest.autoload("GameSession")
	session.accept_local_input = false
	session.start_run(&"crypt", 1, seed_value)
	var content := DDTest.autoload("ContentDB")
	# Runtime load so autoload names exist (`-s` compiles class_name deps before autoloads).
	var monster_script: GDScript = load("res://src/monster/monster.gd")
	var parts: PackedStringArray = []
	for room in session.run.blueprint.rooms:
		for monster_id in room.monster_ids:
			var mdef: MonsterDef = content.get_monster(monster_id)
			if mdef == null:
				continue
			var mob: Node = monster_script.new()
			mob.call("setup", mdef, session.run.effective_tier)
			# Patrol ticks consume ai_rng only. Avoid global_position (nodes are not in-tree here).
			for _i in 4:
				mob.call("_pick_patrol")
			parts.append("id=%s" % str(mob.get("entity_id")))
			var patrol: Vector3 = mob.get("patrol_target")
			parts.append("patrol=%.3f,%.3f" % [patrol.x, patrol.z])
			mob.free()
	for cmd in cmds:
		session.submit_command(cmd)
		session.tick(0.016)
	parts.append("loot=%s" % _loot_fingerprint(session))
	session.end_run(false)
	session.accept_local_input = true
	DDTest.autoload("SaveService").clear_save()
	return "|".join(parts)
