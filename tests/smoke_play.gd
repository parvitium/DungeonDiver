extends Node
## Scene-based smoke: autoloads are bound, unlike `godot -s` scripts.
##   godot --headless --path . res://tests/smoke_play.tscn


func _ready() -> void:
	var failed := 0
	failed += _check(GameSession != null, "GameSession autoload")
	failed += _check(ContentDB.dungeons.size() >= 2, "two dungeon types")
	failed += _check(ContentDB.monsters.size() >= 4, "monsters loaded")

	var def: DungeonTypeDef = ContentDB.get_dungeon(&"crypt")
	var blueprint := DungeonGenerator.generate(def, 1, 99)
	var world := Node3D.new()
	add_child(world)
	DungeonBuilder.new().build(world, blueprint, def, false)

	var player := Player.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0.25, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var start := player.global_position
	var move_cmd := PlayerCommand.new()
	move_cmd.move = Vector2(0, -1)
	GameSession.submit_command(move_cmd)
	GameSession.tick(0.05)
	failed += _check(player.global_position.distance_to(start) > 0.05, "session inbox moves pawn")

	var mob := Monster.new()
	var monster_def: MonsterDef = ContentDB.get_monster(&"skeleton")
	world.add_child(mob)
	mob.set_physics_process(false)
	mob.setup(monster_def, 1)
	mob.global_position = player.global_position + -player.global_transform.basis.z * 1.3
	await get_tree().physics_frame
	var hp_before := mob.health
	var melee_cmd := PlayerCommand.new()
	melee_cmd.melee = true
	player.apply_command(melee_cmd, 0.016)
	failed += _check(mob.health < hp_before, "melee shapecast hits")

	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	failed += _check(hub.get_child_count() > 3, "hub constructs world+ui")

	GameSession.start_run(&"cavern", 2, 7)
	failed += _check(GameSession.run != null, "start cavern run")
	failed += _check(GameSession.run.blueprint.layout_is_connected(), "cavern connected")
	failed += _check(GameSession.run.blueprint.has_boss_and_exit(), "cavern boss+exit")
	GameSession.end_run(true)
	failed += _check(GameSession.profile.progression.dungeon_conquered(&"cavern"), "conquest recorded")

	if failed == 0:
		print("SMOKE_PLAY OK")
		get_tree().quit(0)
	else:
		print("SMOKE_PLAY FAIL %d" % failed)
		get_tree().quit(1)


func _check(ok: bool, message: String) -> int:
	print(("OK  " if ok else "FAIL  ") + message)
	return 0 if ok else 1
