extends Node3D

var _ui: Control
var _depth: int = 1
var _selected: StringName = &"crypt"
var _load_notice: String = ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSession.ui_open = true
	_try_continue()
	_build_room()
	_build_ui()


func _try_continue() -> void:
	if SaveService.has_save():
		_apply_load_result(SaveService.load_game())
	elif not SaveService.last_quarantine_path.is_empty():
		_apply_load_result(false)


func load_notice_text() -> String:
	return _load_notice


func _build_room() -> void:
	var def: DungeonTypeDef = ContentDB.get_dungeon(&"crypt")
	VisualLook.attach_world(self, def)
	var theme := &"crypt"
	var origin := Vector3.ZERO
	var floor := DungeonKit.slab(Vector3(18, 0.4, 18), PBRLibrary.floor_mat(theme), "floor", 1.0)
	floor.position = Vector3(0, -0.2, 0)
	add_child(floor)
	var ceiling := DungeonKit.slab(Vector3(18, 0.3, 18), PBRLibrary.ceiling(theme), "ceiling", 1.0)
	ceiling.position = Vector3(0, 4.4, 0)
	add_child(ceiling)
	for wall in [
		[Vector3(0, 2.1, -9), Vector3(18, 4.2, 0.45), "n"],
		[Vector3(0, 2.1, 9), Vector3(18, 4.2, 0.45), "s"],
		[Vector3(9, 2.1, 0), Vector3(0.45, 4.2, 18), "e"],
		[Vector3(-9, 2.1, 0), Vector3(0.45, 4.2, 18), "w"],
	]:
		DungeonKit.wall_run(self, wall[0], wall[1], false, theme, wall[2])
	DungeonKit.pillars(self, origin, theme)
	DungeonKit.torch_at(self, Vector3(-6.5, 2.2, -6.2), true)
	DungeonKit.torch_at(self, Vector3(6.5, 2.2, 5.4), false)
	DungeonKit.place_prop(self, Vector3(5.2, 0, -4.6), "barrel", theme)
	DungeonKit.place_prop(self, Vector3(-5.4, 0, 4.8), "bones", theme)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	DungeonKit.banner_at(self, Vector3(-7.6, 2.3, 0.0), theme, Color(0.28, 0.10, 0.16), true)
	DungeonKit.banner_at(self, Vector3(7.6, 2.3, 0.0), theme, Color(0.16, 0.12, 0.28), true)
	DungeonKit.debris_at(self, Vector3(6.2, 0, 6.4), theme, rng)
	DungeonKit.debris_at(self, Vector3(-6.4, 0, -6.1), theme, rng)
	DungeonKit.puddle_at(self, Vector3(2.4, 0, 3.2), Vector3(1.4, 0.01, 0.8))
	DungeonKit.puddle_at(self, Vector3(-3.1, 0, -2.6), Vector3(1.0, 0.01, 0.55))
	var pedestal := DungeonKit.slab(Vector3(2.0, 0.9, 2.0), PBRLibrary.trim(theme), "plinth", 0.55)
	pedestal.position = Vector3(0, 0.45, -1.2)
	add_child(pedestal)
	var relic := MeshFactory.visual(MeshFactory.cylinder(0.08, 1.3, 10, 0.4), PBRLibrary.metal(), "Relic")
	relic.position = Vector3(0, 1.55, -1.2)
	add_child(relic)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.1, 8.2)
	cam.fov = 60.0
	add_child(cam)
	cam.look_at(Vector3(0, 1.3, -1.0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_refresh_ui()


func _refresh_ui() -> void:
	if _ui == null:
		return
	while _ui.get_child_count() > 0:
		_ui.get_child(0).free()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	_ui.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(ThemeFactory.label("Choose your descent", 36, Color(0.96, 0.84, 0.48)))
	root.add_child(ThemeFactory.label("Conquer every dungeon. Catalog every beast. Gear grows with depth.", 16, Color(0.8, 0.74, 0.6)))
	if not _load_notice.is_empty():
		root.add_child(ThemeFactory.label(_load_notice, 16, Color(0.95, 0.55, 0.4)))
		root.add_child(ThemeFactory.label("Choose New Game to start over.", 14, Color(0.85, 0.65, 0.45)))

	var monsters := ContentDB.monster_ids()
	var dungeons := ContentDB.dungeon_ids()
	var found := GameSession.profile.progression.discovered_count(monsters)
	var clears := GameSession.profile.progression.conquered_count(dungeons)
	root.add_child(ThemeFactory.label("Collection  %d/%d monsters   %d/%d dungeons" % [found, monsters.size(), clears, dungeons.size()], 16, Color(0.85, 0.75, 0.5)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	for dungeon_id in dungeons:
		var def: DungeonTypeDef = ContentDB.get_dungeon(dungeon_id)
		var card := Panel.new()
		card.custom_minimum_size = Vector2(320, 230)
		card.add_theme_stylebox_override("panel", ThemeFactory.panel())
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 12
		box.offset_top = 10
		box.offset_right = -12
		box.offset_bottom = -10
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)
		box.add_child(ThemeFactory.label(def.display_name, 22, def.accent_color.lightened(0.2)))
		box.add_child(ThemeFactory.label("Base tier %d" % def.base_tier, 14))
		var desc := ThemeFactory.label(def.description, 14, Color(0.75, 0.7, 0.58), true)
		desc.custom_minimum_size = Vector2(280, 0)
		box.add_child(desc)
		var cleared := GameSession.profile.progression.highest_clear(def.id)
		box.add_child(ThemeFactory.label("Best clear: depth %d" % cleared if cleared > 0 else "Not yet conquered", 14, Color(0.7, 0.85, 0.55) if cleared > 0 else Color(0.6, 0.55, 0.45)))
		var enter := Button.new()
		enter.text = "Enter at depth %d" % _depth if _selected == def.id else "Select"
		ThemeFactory.apply_button(enter)
		enter.pressed.connect(_select_or_enter.bind(def.id))
		box.add_child(enter)
		row.add_child(card)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	controls.add_child(ThemeFactory.label("Depth", 16))
	for d in range(1, 4):
		var btn := Button.new()
		btn.text = str(d)
		ThemeFactory.apply_button(btn)
		if d == _depth:
			btn.modulate = Color(1.2, 1.1, 0.7)
		btn.pressed.connect(_set_depth.bind(d))
		controls.add_child(btn)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	actions.add_child(_btn("Open pack (I)", _open_inv))
	actions.add_child(_btn("Bestiary (B)", _open_bestiary))
	actions.add_child(_btn("Settings", _open_settings))
	actions.add_child(_btn("Title", func() -> void: get_tree().change_scene_to_file("res://scenes/title.tscn")))
	actions.add_child(_btn("Save", func() -> void: SaveService.save_game()))
	actions.add_child(_btn("Load / Continue", _load_pressed))
	actions.add_child(_btn("New game", _new_game))

	var inv := preload("res://src/ui/inventory_panel.gd").new()
	inv.visible = false
	inv.name = "Inv"
	_ui.add_child(inv)
	var best := preload("res://src/ui/bestiary_panel.gd").new()
	best.visible = false
	best.name = "Best"
	_ui.add_child(best)
	var settings := SettingsPanel.new()
	settings.visible = false
	settings.name = "Settings"
	_ui.add_child(settings)


func _btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	return btn


func _set_depth(value: int) -> void:
	_depth = value
	_refresh_ui()


func _select_or_enter(id: StringName) -> void:
	if _selected != id:
		_selected = id
		_refresh_ui()
		return
	GameSession.start_run(id, _depth)
	get_tree().change_scene_to_file("res://scenes/dungeon_run.tscn")


func _open_inv() -> void:
	var panel := _ui.get_node("Inv")
	panel.visible = not panel.visible
	if panel.visible:
		panel.refresh()
		_ui.get_node("Best").visible = false
		_ui.get_node("Settings").visible = false


func _open_bestiary() -> void:
	var panel := _ui.get_node("Best")
	panel.visible = not panel.visible
	if panel.visible:
		panel.refresh()
		_ui.get_node("Inv").visible = false
		_ui.get_node("Settings").visible = false


func _open_settings() -> void:
	var panel := _ui.get_node("Settings")
	panel.visible = not panel.visible
	if panel.visible:
		_ui.get_node("Inv").visible = false
		_ui.get_node("Best").visible = false


func _apply_load_result(ok: bool) -> void:
	if ok:
		_load_notice = ""
	else:
		_load_notice = SaveService.load_failure_message()


func _load_pressed() -> void:
	if not SaveService.has_save():
		_load_notice = "No save to load."
		_refresh_ui()
		return
	_apply_load_result(SaveService.load_game())
	_refresh_ui()


func _new_game() -> void:
	_load_notice = ""
	GameSession.reset_profile()
	SaveService.clear_save()
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_open_inv()
	elif event.is_action_pressed("toggle_bestiary"):
		_open_bestiary()
