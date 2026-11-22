extends SceneTree
## Headless test runner. Exit code 0 on success, 1 on failure.
##   godot --headless --path . -s res://tests/run_tests.gd

const TestStatsScript := preload("res://tests/test_stats.gd")
const TestLootScript := preload("res://tests/test_loot.gd")
const TestCombatScript := preload("res://tests/test_combat.gd")
const TestInventoryScript := preload("res://tests/test_inventory.gd")
const TestProgressionScript := preload("res://tests/test_progression.gd")
const TestDungeonGenScript := preload("res://tests/test_dungeon_gen.gd")
const TestSaveScript := preload("res://tests/test_save.gd")
const TestContentScript := preload("res://tests/test_content.gd")
const TestCommandScript := preload("res://tests/test_command.gd")
const TestMouseLookScript := preload("res://tests/test_mouse_look.gd")
const TestVisualsScript := preload("res://tests/test_visuals.gd")
const TestGameplayScript := preload("res://tests/test_gameplay.gd")
const TestTownScript := preload("res://tests/test_town.gd")


func _initialize() -> void:
	print("DungeonDiver tests starting")
	# `-s` _initialize runs before the SceneTree is inside the tree, so physics
	# queries and Node3D.global_position fail. Run after the first physics frame.
	call_deferred("_after_enter_tree")


func _after_enter_tree() -> void:
	_boot_autoloads()
	# process_frame, not physics_frame: bodies spawned during a physics callback
	# are not queryable until the next step.
	if process_frame.is_connected(_run_and_quit):
		return
	process_frame.connect(_run_and_quit, CONNECT_ONE_SHOT)


func _run_and_quit() -> void:
	var code: int = await _run()
	print("DungeonDiver tests finished with code %d" % code)
	quit(code)


func _boot_autoloads() -> void:
	# `-s` SceneTree._initialize runs before autoload _ready. Load content first.
	var content := root.get_node_or_null("ContentDB")
	if content and content.has_method("reload"):
		content.reload()
	var session := root.get_node_or_null("GameSession")
	if session and session.has_method("reset_profile"):
		session.reset_profile(false)


func _run() -> int:
	var suites: Array = []
	suites.append(await _suite(TestStatsScript, "stats"))
	suites.append(await _suite(TestLootScript, "loot"))
	suites.append(await _suite(TestCombatScript, "combat"))
	suites.append(await _suite(TestInventoryScript, "inventory"))
	suites.append(await _suite(TestProgressionScript, "progression"))
	suites.append(await _suite(TestDungeonGenScript, "dungeon_gen"))
	suites.append(await _suite(TestSaveScript, "save"))
	suites.append(await _suite(TestContentScript, "content"))
	suites.append(await _suite(TestCommandScript, "command"))
	suites.append(await _suite(TestMouseLookScript, "mouse_look"))
	suites.append(await _suite(TestVisualsScript, "visuals"))
	suites.append(await _suite(TestGameplayScript, "gameplay"))
	suites.append(await _suite(TestTownScript, "town"))
	suites.append(_smoke())
	suites.append(_smoke_all_dungeons())

	var passed := 0
	var failed := 0
	for suite in suites:
		if suite == null:
			failed += 1
			print("FAIL  <null suite>")
			continue
		passed += suite.passed
		failed += suite.failed
		var mark := "OK" if suite.failed == 0 else "FAIL"
		print("%s  %s  %d passed  %d failed" % [mark, suite.suite_name, suite.passed, suite.failed])
		for err in suite.errors:
			print("    ", err)

	print("----")
	print("Total  %d passed  %d failed" % [passed, failed])
	return 1 if failed > 0 else 0


func _suite(script: GDScript, suite_name: String) -> DDTest:
	if script == null or not script.has_method("run"):
		return DDTest.compile_failure(suite_name, "suite script failed to compile")
	var result: Variant = await script.run()
	if result is DDTest:
		return result
	return DDTest.compile_failure(suite_name, "suite did not return DDTest")


func _smoke() -> DDTest:
	var t := DDTest.new("smoke_dungeon_build")
	var def: DungeonTypeDef = Catalog.all_dungeons()[0]
	var blueprint := DungeonGenerator.generate(def, 1, 2026)
	var world := Node3D.new()
	root.add_child(world)
	var builder := DungeonBuilder.new()
	var markers: Dictionary = builder.build(world, blueprint, def, false)
	t.assert_true(markers.has("player"), "player marker")
	t.assert_gt(float((markers["spawns"] as Array).size()), 0.0, "monster markers")
	t.assert_true(markers["exit"] != null, "exit marker")
	t.assert_true(markers["nav"] != null, "nav region")
	t.assert_gt(float(world.get_child_count()), 5.0, "geometry spawned")
	world.free()
	return t


func _smoke_all_dungeons() -> DDTest:
	var t := DDTest.new("smoke_all_dungeons")
	var session := root.get_node_or_null("GameSession")
	var content := root.get_node_or_null("ContentDB")
	if session == null or content == null:
		t.assert_true(false, "autoloads present")
		return t
	var ids: Array = content.dungeon_ids()
	t.assert_ge(float(ids.size()), 2.0, "at least two dungeons")
	for dungeon_id in ids:
		var run: DungeonRunState = session.start_run(dungeon_id, 1, 2026)
		t.assert_true(run != null, "%s starts" % String(dungeon_id))
		if run == null:
			continue
		t.assert_true(run.blueprint != null, "%s blueprint" % String(dungeon_id))
		if run.blueprint:
			t.assert_true(run.blueprint.layout_is_connected(), "%s connected" % String(dungeon_id))
			t.assert_true(run.blueprint.has_boss_and_exit(), "%s boss+exit" % String(dungeon_id))
		var def: DungeonTypeDef = content.get_dungeon(dungeon_id)
		var world := Node3D.new()
		root.add_child(world)
		var markers: Dictionary = DungeonBuilder.new().build(world, run.blueprint, def, false)
		t.assert_true(markers.has("player"), "%s player marker" % String(dungeon_id))
		t.assert_true(markers["exit"] != null, "%s exit marker" % String(dungeon_id))
		world.free()
		session.end_run(false)
	return t
