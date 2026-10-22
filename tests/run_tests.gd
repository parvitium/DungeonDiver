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
const TestSettingsScript := preload("res://tests/test_settings.gd")
const TestVisualsScript := preload("res://tests/test_visuals.gd")


func _initialize() -> void:
	print("DungeonDiver tests starting")
	_boot_autoloads()
	var code := _run()
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
	var settings := root.get_node_or_null("SettingsService")
	if settings and settings.has_method("apply"):
		settings.apply()


func _run() -> int:
	var suites: Array = [
		_suite(TestStatsScript, "stats"),
		_suite(TestLootScript, "loot"),
		_suite(TestCombatScript, "combat"),
		_suite(TestInventoryScript, "inventory"),
		_suite(TestProgressionScript, "progression"),
		_suite(TestDungeonGenScript, "dungeon_gen"),
		_suite(TestSaveScript, "save"),
		_suite(TestContentScript, "content"),
		_suite(TestCommandScript, "command"),
		_suite(TestSettingsScript, "settings"),
		_suite(TestVisualsScript, "visuals"),
		_smoke(),
	]

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
	return script.call("run")


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
