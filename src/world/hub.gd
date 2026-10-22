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


func load_notice_text() -> String:
	return _load_notice


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.04, 0.035)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.35, 0.25)
	e.ambient_light_energy = 0.5
	e.fog_enabled = true
	e.fog_density = 0.02
	env.environment = e
	add_child(env)
	var floor := Greybox.make_box(Vector3(18, 0.4, 18), Color(0.2, 0.16, 0.12))
	floor.position = Vector3(0, -0.2, 0)
	add_child(floor)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.2, 8.5)
	add_child(cam)
	cam.look_at(Vector3(0, 1.2, 0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4, 2)
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 3.0
	light.omni_range = 16
	add_child(light)
	var pedestal := Greybox.make_box(Vector3(2.2, 1.0, 2.2), Color(0.35, 0.25, 0.14))
	pedestal.position = Vector3(0, 0.5, 0)
	add_child(pedestal)
	var relic := Greybox.make_box(Vector3(0.25, 1.4, 0.25), Color(0.75, 0.75, 0.82), false)
	relic.position = Vector3(0, 1.6, 0)
	add_child(relic)


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
	root.add_child(ThemeFactory.label("DungeonDiver", 42, Color(0.95, 0.82, 0.42)))
	root.add_child(ThemeFactory.label("Conquer every dungeon. Catalog every beast. Get cooler gear as you go deeper.", 16, Color(0.8, 0.74, 0.6)))
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
		card.custom_minimum_size = Vector2(320, 210)
		card.add_theme_stylebox_override("panel", ThemeFactory.panel())
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 12
		box.offset_top = 10
		box.offset_right = -12
		box.offset_bottom = -10
		card.add_child(box)
		box.add_child(ThemeFactory.label(def.display_name, 22, def.accent_color.lightened(0.2)))
		box.add_child(ThemeFactory.label("Base tier %d" % def.base_tier, 14))
		box.add_child(ThemeFactory.label(def.description, 14, Color(0.75, 0.7, 0.58)))
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


func _open_bestiary() -> void:
	var panel := _ui.get_node("Best")
	panel.visible = not panel.visible
	if panel.visible:
		panel.refresh()
		_ui.get_node("Inv").visible = false


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
