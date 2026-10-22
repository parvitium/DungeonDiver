class_name TestSave
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("save")
	_happy_path(t)
	_reject_bad_types(t)
	_reject_future_version(t)
	_drop_unknown_ids(t)
	_clamp_enums(t)
	_quarantine_corrupt(t)
	_hub_load_failure(t)
	_title_preserves_save_notice(t)
	return t


static func _happy_path(t: DDTest) -> void:
	var profile := PlayerProfile.new()
	var item := ItemInstance.new()
	item.instance_id = "keep"
	item.def_id = &"rusty_sword"
	item.display_name = "Rusty Sword"
	item.slot = DD.EquipSlot.WEAPON
	item.rarity = DD.Rarity.RARE
	item.item_level = 2
	item.stats = StatBlock.new(8, 0, 0, 0, 0)
	profile.inventory.add_item(item)
	profile.inventory.equip("keep")
	profile.progression.record_kill(&"wraith")
	profile.progression.record_clear(&"cavern", 2)
	profile.current_health = 77

	var payload := SaveCodec.payload_from_profile(profile)
	t.assert_eq(int(payload.get("version", 0)), DD.SAVE_VERSION, "version")
	var loaded := SaveCodec.profile_from_payload(payload)
	t.assert_true(loaded != null, "valid payload decodes")
	t.assert_eq(loaded.current_health, 77.0, "health restored")
	t.assert_eq(loaded.progression.kills_of(&"wraith"), 1, "bestiary restored")
	t.assert_eq(loaded.progression.highest_clear(&"cavern"), 2, "dungeon log restored")
	t.assert_eq(loaded.inventory.equipped_stats().attack, 8.0, "gear restored")
	t.assert_eq(loaded.inventory.equipped[DD.EquipSlot.WEAPON].rarity, DD.Rarity.RARE, "rarity restored")
	var minimal := SaveCodec.decode_payload({"version": DD.SAVE_VERSION, "profile": {}})
	t.assert_true(minimal != null, "missing fields default")
	t.assert_eq(minimal.display_name, "Diver", "default name")


static func _reject_bad_types(t: DDTest) -> void:
	var cases: Array = [
		["inventory string", {"version": 1, "profile": {"inventory": "not-a-dict"}}],
		["item stats string", {"version": 1, "profile": {"inventory": {"items": [{"def_id": "rusty_sword", "stats": "nope"}]}}}],
		["equipped object", {"version": 1, "profile": {"inventory": {"equipped": {"0": {"def_id": "rusty_sword"}}}}}],
		["progression string", {"version": 1, "profile": {"progression": "nope"}}],
		["profile string", {"version": 1, "profile": "nope"}],
		["health string", {"version": 1, "profile": {"current_health": "full"}}],
		["bestiary entry string", {"version": 1, "profile": {"progression": {"bestiary": {"skeleton": "lots"}}}}],
		["conquered string depth", {"version": 1, "profile": {"progression": {"conquered": {"crypt": "deep"}}}}],
		["items not array", {"version": 1, "profile": {"inventory": {"items": {"def_id": "rusty_sword"}}}}],
		["null payload", null],
		["array payload", [1, 2, 3]],
	]
	for case in cases:
		var label: String = case[0]
		var payload: Variant = case[1]
		t.assert_true(SaveCodec.decode_payload(payload) == null, "decode rejects %s" % label)
		var session := DDTest.autoload("GameSession")
		var saves := DDTest.autoload("SaveService")
		var before: Variant = session.profile
		var marker := "KeepMe-%s" % label
		session.profile.display_name = marker
		t.assert_false(saves.apply_payload(payload), "apply_payload false for %s" % label)
		t.assert_eq(session.profile, before, "profile untouched for %s" % label)
		t.assert_eq(session.profile.display_name, marker, "name untouched for %s" % label)
	DDTest.autoload("GameSession").profile.display_name = "Diver"


static func _reject_future_version(t: DDTest) -> void:
	var payload := {
		"version": 99,
		"profile": {
			"display_name": "FromTheFuture",
			"current_health": 12.0,
		},
	}
	t.assert_true(SaveCodec.decode_payload(payload) == null, "future version decode null")
	var session := DDTest.autoload("GameSession")
	var saves := DDTest.autoload("SaveService")
	session.profile.display_name = "Present"
	t.assert_false(saves.apply_payload(payload), "future version apply false")
	t.assert_eq(session.profile.display_name, "Present", "future version leaves profile")
	session.profile.display_name = "Diver"


static func _drop_unknown_ids(t: DDTest) -> void:
	var payload := {
		"version": DD.SAVE_VERSION,
		"profile": {
			"display_name": "Sanitized",
			"inventory": {
				"items": [
					{
						"instance_id": "real",
						"def_id": "rusty_sword",
						"display_name": "Rusty Sword",
						"slot": 0,
						"rarity": 0,
						"item_level": 1,
						"stats": {"attack": 6.0},
					},
					{
						"instance_id": "fake",
						"def_id": "not_a_real_item",
						"display_name": "Phantom",
						"slot": 0,
						"rarity": 0,
						"item_level": 1,
						"stats": {"attack": 99.0},
					},
				],
				"equipped": [
					{
						"instance_id": "ghost-equip",
						"def_id": "also_fake",
						"display_name": "Ghost Helm",
						"slot": 2,
						"rarity": 2,
						"stats": {"defense": 9.0},
					},
					null, null, null, null, null,
				],
			},
			"progression": {
				"bestiary": {
					"skeleton": {"kills": 3, "first_unix": 1},
					"not_a_monster": {"kills": 9, "first_unix": 1},
				},
				"conquered": {
					"crypt": 2,
					"made_up_dungeon": 9,
				},
			},
		},
	}
	var session := DDTest.autoload("GameSession")
	var saves := DDTest.autoload("SaveService")
	t.assert_true(saves.apply_payload(payload), "unknown ids still load")
	t.assert_eq(session.profile.display_name, "Sanitized", "known fields kept")
	t.assert_eq(session.profile.inventory.items.size(), 1, "unknown bag item dropped")
	if session.profile.inventory.items.size() == 1:
		t.assert_eq(String(session.profile.inventory.items[0].def_id), "rusty_sword", "kept rusty sword")
	else:
		t.assert_true(false, "kept rusty sword")
	t.assert_true(session.profile.inventory.equipped[DD.EquipSlot.HEAD] == null, "unknown equipped dropped")
	t.assert_eq(session.profile.progression.kills_of(&"skeleton"), 3, "known monster kept")
	t.assert_eq(session.profile.progression.kills_of(&"not_a_monster"), 0, "unknown monster dropped")
	t.assert_eq(session.profile.progression.highest_clear(&"crypt"), 2, "known dungeon kept")
	t.assert_eq(session.profile.progression.highest_clear(&"made_up_dungeon"), 0, "unknown dungeon dropped")
	session.reset_profile(false)


static func _clamp_enums(t: DDTest) -> void:
	var payload := {
		"version": DD.SAVE_VERSION,
		"profile": {
			"inventory": {
				"items": [{
					"instance_id": "clamp",
					"def_id": "rusty_sword",
					"display_name": "Rusty Sword",
					"slot": 99,
					"rarity": -3,
					"item_level": 1,
					"stats": {"attack": 4.0},
				}],
			},
		},
	}
	var session := DDTest.autoload("GameSession")
	t.assert_true(DDTest.autoload("SaveService").apply_payload(payload), "clamped enums load")
	t.assert_eq(session.profile.inventory.items.size(), 1, "clamped item kept")
	if session.profile.inventory.items.size() == 1:
		var item: ItemInstance = session.profile.inventory.items[0]
		t.assert_in_range(float(item.slot), 0.0, 5.0, "slot clamped")
		t.assert_in_range(float(item.rarity), 0.0, 4.0, "rarity clamped")
	session.reset_profile(false)


static func _quarantine_corrupt(t: DDTest) -> void:
	var path := "user://dd_qa_corrupt.json"
	var session := DDTest.autoload("GameSession")
	var saves := DDTest.autoload("SaveService")
	_cleanup_quarantine(saves, path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "profile": "not-a-dict"}))
	file.close()
	session.profile.display_name = "BeforeCorruptLoad"
	t.assert_false(saves.load_game(path), "corrupt load fails")
	t.assert_eq(session.profile.display_name, "BeforeCorruptLoad", "corrupt load leaves profile")
	t.assert_false(FileAccess.file_exists(path), "corrupt original removed")
	t.assert_true(not saves.last_quarantine_path.is_empty(), "quarantine path recorded")
	t.assert_true(FileAccess.file_exists(saves.last_quarantine_path), "quarantine copy exists")
	t.assert_true(saves.last_quarantine_path.contains(".corrupt-"), "quarantine suffix")
	t.assert_true(
		saves.load_failure_message().begins_with("Save couldn't be loaded; backed up to"),
		"failure message names the backup"
	)
	t.assert_true(saves.load_failure_message().contains(saves.last_quarantine_path), "message includes path")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.last_quarantine_path))

	var future_path := "user://dd_qa_future.json"
	_cleanup_quarantine(saves, future_path)
	file = FileAccess.open(future_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 99, "profile": {"display_name": "FromTheFuture"}}))
	file.close()
	session.profile.display_name = "StillPresent"
	t.assert_false(saves.load_game(future_path), "future version load fails")
	t.assert_eq(session.profile.display_name, "StillPresent", "future version leaves profile")
	t.assert_false(FileAccess.file_exists(future_path), "future original removed")
	t.assert_true(
		saves.load_failure_message().begins_with("Save couldn't be loaded; backed up to"),
		"future version backup message"
	)
	if not saves.last_quarantine_path.is_empty() and FileAccess.file_exists(saves.last_quarantine_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.last_quarantine_path))
	session.reset_profile(false)


static func _hub_load_failure(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	var saves := DDTest.autoload("SaveService")
	var tree := Engine.get_main_loop() as SceneTree
	_cleanup_quarantine(saves, DD.SAVE_PATH)
	session.profile.display_name = "KeepHub"

	var hub: Node = (load("res://src/world/hub.gd") as GDScript).new()
	tree.root.add_child(hub)
	hub.call("_try_continue")
	t.assert_eq(hub.load_notice_text(), "", "no notice without save")
	t.assert_eq(session.profile.display_name, "KeepHub", "hub boot without save leaves profile")

	var file := FileAccess.open(DD.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "profile": "not-a-dict"}))
	file.close()
	hub.call("_load_pressed")
	t.assert_eq(session.profile.display_name, "KeepHub", "Load failure does not start a new game")
	t.assert_false(FileAccess.file_exists(DD.SAVE_PATH), "Load quarantines the file")
	var notice: String = hub.load_notice_text()
	t.assert_true(
		notice.begins_with("Save couldn't be loaded; backed up to"),
		"Load shows backup message"
	)
	t.assert_true(notice.contains(".corrupt-"), "Load message includes backup path")

	hub.call("_new_game")
	t.assert_eq(hub.load_notice_text(), "", "New Game clears notice")
	t.assert_eq(session.profile.display_name, "Diver", "New Game is an explicit reset")

	hub.free()
	_cleanup_quarantine(saves, DD.SAVE_PATH)

	session.profile.display_name = "BootKeep"
	file = FileAccess.open(DD.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 99, "profile": {"display_name": "FromTheFuture"}}))
	file.close()
	var continue_hub: Node = (load("res://src/world/hub.gd") as GDScript).new()
	tree.root.add_child(continue_hub)
	continue_hub.call("_try_continue")
	t.assert_eq(session.profile.display_name, "BootKeep", "Continue failure does not start a new game")
	t.assert_true(
		continue_hub.load_notice_text().begins_with("Save couldn't be loaded; backed up to"),
		"Continue shows backup message"
	)
	continue_hub.free()
	session.ui_open = false
	_cleanup_quarantine(saves, DD.SAVE_PATH)
	session.reset_profile(false)


static func _title_preserves_save_notice(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	var saves := DDTest.autoload("SaveService")
	var tree := Engine.get_main_loop() as SceneTree
	_cleanup_quarantine(saves, DD.SAVE_PATH)
	session.profile.display_name = "TitleKeep"
	var file := FileAccess.open(DD.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "profile": "not-a-dict"}))
	file.close()

	var title: Node = (load("res://src/world/title.gd") as GDScript).new()
	tree.root.add_child(title)
	if title.get_child_count() == 0:
		title.call("_ready")
	t.assert_true(FileAccess.file_exists(DD.SAVE_PATH), "title boot leaves the save file")
	t.assert_eq(saves.last_quarantine_path, "", "title boot does not quarantine")
	t.assert_eq(session.profile.display_name, "TitleKeep", "title boot leaves profile")
	title.free()

	var hub: Node = (load("res://src/world/hub.gd") as GDScript).new()
	tree.root.add_child(hub)
	hub.call("_try_continue")
	t.assert_eq(session.profile.display_name, "TitleKeep", "hub still does not start a new game")
	t.assert_true(
		hub.load_notice_text().begins_with("Save couldn't be loaded; backed up to"),
		"hub still shows the corrupted-save notice"
	)
	t.assert_true(hub.load_notice_text().contains(".corrupt-"), "hub notice includes backup path")
	hub.free()
	session.ui_open = false
	_cleanup_quarantine(saves, DD.SAVE_PATH)
	session.reset_profile(false)


static func _cleanup_quarantine(saves: Node, path: String) -> void:
	saves.clear_save(path)
	if not saves.last_quarantine_path.is_empty() and FileAccess.file_exists(saves.last_quarantine_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.last_quarantine_path))
	saves.last_quarantine_path = ""
