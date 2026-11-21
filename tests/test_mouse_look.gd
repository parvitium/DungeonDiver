class_name TestMouseLook
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("mouse_look")
	_policy(t)
	_settings(t)
	_hud_capture_transitions(t)
	_yaw_pitch(t)
	_ingest_and_recapture(t)
	_restore()
	return t


static func _policy(t: DDTest) -> void:
	t.assert_eq(
		MouseCapture.context_for(false, false),
		MouseCapture.Context.HUB,
		"hub context"
	)
	t.assert_eq(
		MouseCapture.context_for(false, true),
		MouseCapture.Context.HUB,
		"hub ignores ui_open"
	)
	t.assert_eq(
		MouseCapture.context_for(true, false),
		MouseCapture.Context.DUNGEON_PLAY,
		"dungeon play context"
	)
	t.assert_eq(
		MouseCapture.context_for(true, true),
		MouseCapture.Context.DUNGEON_UI,
		"dungeon ui context"
	)
	t.assert_eq(
		MouseCapture.mode_for(MouseCapture.Context.HUB),
		Input.MOUSE_MODE_VISIBLE,
		"hub visible"
	)
	t.assert_eq(
		MouseCapture.mode_for(MouseCapture.Context.DUNGEON_UI),
		Input.MOUSE_MODE_VISIBLE,
		"ui visible"
	)
	t.assert_eq(
		MouseCapture.mode_for(MouseCapture.Context.DUNGEON_PLAY),
		Input.MOUSE_MODE_CAPTURED,
		"play captured"
	)
	t.assert_false(
		MouseCapture.should_recapture_click(MouseCapture.Context.HUB, false),
		"hub click does not capture"
	)
	t.assert_false(
		MouseCapture.should_recapture_click(MouseCapture.Context.DUNGEON_UI, false),
		"ui click does not steal capture"
	)
	t.assert_false(
		MouseCapture.should_recapture_click(MouseCapture.Context.DUNGEON_PLAY, true),
		"already captured skip"
	)
	t.assert_true(
		MouseCapture.should_recapture_click(MouseCapture.Context.DUNGEON_PLAY, false),
		"play click recaptures"
	)
	MouseCapture.apply(MouseCapture.Context.HUB)
	t.assert_false(MouseCapture.is_captured(), "apply hub")
	t.assert_false(MouseCapture.allows_look(), "hub does not look")
	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	t.assert_true(MouseCapture.is_captured(), "apply play")
	t.assert_true(MouseCapture.allows_look(), "play allows look")
	MouseCapture.apply(MouseCapture.Context.DUNGEON_UI)
	t.assert_false(MouseCapture.is_captured(), "apply ui")
	t.assert_false(MouseCapture.allows_look(), "ui does not look")
	t.assert_eq(MouseCapture.clamp_pitch(deg_to_rad(-120.0)), deg_to_rad(-85.0), "pitch floor")
	t.assert_eq(MouseCapture.clamp_pitch(deg_to_rad(120.0)), deg_to_rad(85.0), "pitch ceiling")


static func _settings(t: DDTest) -> void:
	var settings := LookSettings.new()
	settings.apply_dict({"mouse_sensitivity": 99.0, "invert_y": true})
	t.assert_in_range(settings.sensitivity, LookSettings.MIN_SENSITIVITY, LookSettings.MAX_SENSITIVITY, "sens clamped")
	t.assert_true(settings.invert_y, "invert from dict")
	settings.sensitivity = 1.0
	settings.invert_y = false
	var base := settings.scale_delta(Vector2(10, 20))
	t.assert_eq(base, Vector2(10, 20), "default scale")
	settings.sensitivity = 2.0
	var scaled := settings.scale_delta(Vector2(10, 20))
	t.assert_eq(scaled, Vector2(20, 40), "sensitivity 2x")
	settings.sensitivity = 1.0
	settings.invert_y = true
	var inverted := settings.scale_delta(Vector2(10, 20))
	t.assert_eq(inverted, Vector2(10, -20), "invert y flips pitch")

	var path := "user://dd_qa_look.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	settings.sensitivity = 1.55
	settings.invert_y = true
	t.assert_true(settings.save_to_disk(path), "look settings save")
	var loaded := LookSettings.new()
	t.assert_true(loaded.load_from_disk(path), "look settings load")
	t.assert_eq(loaded.sensitivity, 1.55, "sensitivity persisted")
	t.assert_true(loaded.invert_y, "invert y persisted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var session := DDTest.autoload("GameSession")
	session.look_settings.sensitivity = LookSettings.DEFAULT_SENSITIVITY
	session.look_settings.invert_y = false


static func _hud_capture_transitions(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session := DDTest.autoload("GameSession")
	session.ui_open = false
	var hud_script: GDScript = load("res://src/ui/hud.gd")
	var hud: CanvasLayer = hud_script.new()
	tree.root.add_child(hud)
	hud.call("_build")
	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	t.assert_true(MouseCapture.is_captured(), "enter dungeon captures")
	t.assert_false(session.ui_open, "play ui closed")

	hud.call("open_pause")
	t.assert_true(bool(hud.call("is_pause_open")), "pause opens")
	t.assert_true(session.ui_open, "pause sets ui_open")
	t.assert_false(MouseCapture.is_captured(), "pause releases mouse")

	hud.call("close_panels")
	t.assert_false(bool(hud.call("is_pause_open")), "pause closed")
	t.assert_false(session.ui_open, "resume clears ui_open")
	t.assert_true(MouseCapture.is_captured(), "resume recaptures")

	hud.call("open_inventory")
	t.assert_true(bool(hud.call("is_inventory_open")), "inventory opens")
	t.assert_true(session.ui_open, "inventory ui_open")
	t.assert_false(MouseCapture.is_captured(), "inventory releases mouse")
	hud.call("close_panels")
	t.assert_true(MouseCapture.is_captured(), "inventory close recaptures")

	hud.call("open_bestiary")
	t.assert_true(bool(hud.call("is_bestiary_open")), "bestiary opens")
	t.assert_true(session.ui_open, "bestiary ui_open")
	t.assert_false(MouseCapture.is_captured(), "bestiary releases mouse")
	hud.call("close_panels")
	t.assert_true(MouseCapture.is_captured(), "bestiary close recaptures")

	hud.call("open_pause")
	var pause: Control = hud.call("pause_panel")
	t.assert_true(pause != null, "pause panel exists")
	if pause and pause.has_method("_resume"):
		pause.call("_resume")
	t.assert_false(bool(hud.call("is_pause_open")), "pause resume hides panel")
	t.assert_false(session.ui_open, "pause resume clears ui_open")
	t.assert_true(MouseCapture.is_captured(), "pause resume recaptures")

	hud.free()
	session.ui_open = false
	MouseCapture.apply(MouseCapture.Context.HUB)


static func _yaw_pitch(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player_script: GDScript = load("res://src/player/player.gd")
	var player: Node = player_script.new()
	tree.root.add_child(player)
	player.set_physics_process(false)
	player.call("_build_rig")
	var start_yaw: float = player.rotation.y
	player.call("_apply_look", Vector2(80, 30))
	t.assert_true(player.rotation.y != start_yaw, "yaw rotates body")
	t.assert_true(float(player.call("head_pitch")) != 0.0, "pitch stored")
	var head: Node3D = player.get_node("Head")
	t.assert_true(is_equal_approx(head.rotation.x, float(player.get("look_pitch"))), "pitch on head node")
	t.assert_eq(player.get_node("Head/Camera3D").rotation.x, 0.0, "camera local pitch stays 0")

	player.call("_apply_look", Vector2(0, 200000))
	t.assert_in_range(float(player.get("look_pitch")), deg_to_rad(-85.0), deg_to_rad(85.0), "pitch clamped")
	player.free()


static func _ingest_and_recapture(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session := DDTest.autoload("GameSession")
	session.ui_open = false
	session.look_settings.sensitivity = 1.0
	session.look_settings.invert_y = false
	var player_script: GDScript = load("res://src/player/player.gd")
	var player: Node = player_script.new()
	tree.root.add_child(player)
	player.set_physics_process(false)
	player.call("_build_rig")

	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(12, -8)
	t.assert_true(bool(player.call("handle_look_input", motion)), "captured motion is look")
	var gathered: PlayerCommand = player.call("gather_command")
	t.assert_eq(gathered.look_delta.x, 12.0, "look x gathered")
	t.assert_eq(gathered.look_delta.y, -8.0, "look y gathered")

	session.ui_open = true
	MouseCapture.apply(MouseCapture.Context.DUNGEON_UI)
	var blocked := InputEventMouseMotion.new()
	blocked.relative = Vector2(50, 50)
	t.assert_false(bool(player.call("handle_look_input", blocked)), "ui blocks look")
	var empty: PlayerCommand = player.call("gather_command")
	t.assert_eq(empty.look_delta, Vector2.ZERO, "ui look delta empty")

	var ui_click := InputEventMouseButton.new()
	ui_click.pressed = true
	ui_click.button_index = MOUSE_BUTTON_LEFT
	t.assert_false(bool(player.call("handle_look_input", ui_click)), "ui click not recapture")
	t.assert_false(MouseCapture.is_captured(), "ui stays visible")

	session.ui_open = false
	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	MouseCapture.simulate_os_release()
	t.assert_false(MouseCapture.is_captured(), "os release drops capture")
	t.assert_true(
		MouseCapture.should_recapture_click(MouseCapture.Context.DUNGEON_PLAY, MouseCapture.is_captured()),
		"lost capture wants click"
	)
	var play_click := InputEventMouseButton.new()
	play_click.pressed = true
	play_click.button_index = MOUSE_BUTTON_LEFT
	t.assert_true(bool(player.call("handle_look_input", play_click)), "click recaptures in play")
	t.assert_true(MouseCapture.is_captured(), "captured after click")
	var after_click: PlayerCommand = player.call("gather_command")
	t.assert_false(after_click.melee, "recapture click does not melee")

	session.look_settings.invert_y = true
	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	var inv_motion := InputEventMouseMotion.new()
	inv_motion.relative = Vector2(0, 10)
	t.assert_true(bool(player.call("handle_look_input", inv_motion)), "invert motion accepted")
	var inv_cmd: PlayerCommand = player.call("gather_command")
	t.assert_eq(inv_cmd.look_delta.y, -10.0, "invert applied at gather")

	player.free()
	session.look_settings.invert_y = false
	session.ui_open = false


static func _restore() -> void:
	var session := DDTest.autoload("GameSession")
	session.ui_open = false
	session.look_settings.sensitivity = LookSettings.DEFAULT_SENSITIVITY
	session.look_settings.invert_y = false
	MouseCapture.apply(MouseCapture.Context.HUB)
