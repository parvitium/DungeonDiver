extends Node3D
## True title screen. Scenic dungeon hall plus New / Load / Settings / Multiplayer / Exit.

var _ui: Control
var _settings: Control
var _panel: Control
var _mode: String = "home"
var _pending_slot: int = 1
var _notice: String = ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSession.ui_open = true
	GameSession.run = null
	MouseCapture.apply(MouseCapture.Context.HUB)
	ScenicBackdrop.attach(self, 9.4)
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_settings = preload("res://src/ui/settings_panel.gd").new()
	_settings.visible = false
	_refresh()
	_ui.add_child(_settings)


func _refresh() -> void:
	if _ui == null:
		return
	var doomed: Array = []
	for child in _ui.get_children():
		if child == _settings:
			continue
		doomed.append(child)
	for child in doomed:
		child.free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 36)
	_ui.add_child(margin)
	_ui.move_child(margin, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	root.add_child(ThemeFactory.label("DungeonDiver", 54, Color(0.96, 0.84, 0.42)))
	root.add_child(ThemeFactory.label("A torch-lit hall. A pack of steel. Every dungeon still waiting.", 18, Color(0.82, 0.76, 0.62), true))
	if not _notice.is_empty():
		root.add_child(ThemeFactory.label(_notice, 16, Color(0.95, 0.55, 0.4), true))
	_panel = Panel.new()
	_panel.name = "MenuPanel"
	_panel.custom_minimum_size = Vector2(460, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_panel.add_theme_stylebox_override("panel", ThemeFactory.panel())
	root.add_child(_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 18)
	inner.add_theme_constant_override("margin_top", 16)
	inner.add_theme_constant_override("margin_right", 18)
	inner.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	inner.add_child(box)
	match _mode:
		"new_slot":
			_fill_slot_picker(box, true)
		"new_name":
			_fill_new_name(box)
		"load":
			_fill_slot_picker(box, false)
		"multiplayer":
			_fill_multiplayer(box)
		_:
			_fill_home(box)


func _fill_home(box: VBoxContainer) -> void:
	box.add_child(_menu_btn("New Game", open_new_game))
	box.add_child(_menu_btn("Load Game", open_load))
	box.add_child(_menu_btn("Settings", open_settings))
	box.add_child(_menu_btn("Multiplayer", open_multiplayer))
	box.add_child(_menu_btn("Exit Game", _exit_game))


func _fill_slot_picker(box: VBoxContainer, for_new: bool) -> void:
	box.add_child(ThemeFactory.label("Choose a save slot" if for_new else "Load a save slot", 22, Color(0.95, 0.82, 0.45)))
	for info in SaveService.slot_summaries():
		var slot := int(info.get("slot", 1))
		var btn := Button.new()
		btn.text = SaveService.summary_line(info)
		ThemeFactory.apply_button(btn)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if for_new:
			btn.pressed.connect(_choose_new_slot.bind(slot, bool(info.get("occupied", false))))
		else:
			btn.disabled = not bool(info.get("occupied", false)) or bool(info.get("corrupt", false))
			btn.pressed.connect(_load_slot.bind(slot))
		box.add_child(btn)
	box.add_child(_menu_btn("Back", _home))


func _fill_new_name(box: VBoxContainer) -> void:
	box.add_child(ThemeFactory.label("Name your diver", 22, Color(0.95, 0.82, 0.45)))
	box.add_child(ThemeFactory.label("Slot %d  ·  this overwrites that slot." % _pending_slot, 14, Color(0.75, 0.7, 0.55)))
	var edit := LineEdit.new()
	edit.placeholder_text = "Character name"
	edit.text = "Diver"
	edit.max_length = 24
	edit.custom_minimum_size = Vector2(280, 36)
	box.add_child(edit)
	var start := Button.new()
	start.text = "Enter town"
	ThemeFactory.apply_button(start, true)
	start.pressed.connect(func() -> void: _confirm_new(edit.text))
	box.add_child(start)
	box.add_child(_menu_btn("Back", open_new_game))


func _fill_multiplayer(box: VBoxContainer) -> void:
	box.add_child(ThemeFactory.label("Multiplayer", 22, Color(0.95, 0.82, 0.45)))
	box.add_child(ThemeFactory.label("Coming soon", 28, Color(0.95, 0.82, 0.42)))
	box.add_child(ThemeFactory.label("Host and join will live here. A lantern for now, a party later.", 14, Color(0.75, 0.7, 0.55), true))
	var host := Button.new()
	host.text = "Host (coming soon)"
	host.disabled = true
	ThemeFactory.apply_button(host)
	box.add_child(host)
	var join := Button.new()
	join.text = "Join (coming soon)"
	join.disabled = true
	ThemeFactory.apply_button(join)
	box.add_child(join)
	box.add_child(_menu_btn("Back", _home))


func _menu_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 42)
	ThemeFactory.apply_button(btn)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(cb)
	return btn


func open_new_game() -> void:
	_mode = "new_slot"
	_notice = ""
	_refresh()


func open_load() -> void:
	_mode = "load"
	_notice = ""
	_refresh()


func open_settings() -> void:
	_settings.present()


func open_multiplayer() -> void:
	_mode = "multiplayer"
	_refresh()


func _home() -> void:
	_mode = "home"
	_refresh()


func _choose_new_slot(slot: int, occupied: bool) -> void:
	_pending_slot = slot
	if occupied:
		_notice = "Slot %d already has a save. Naming a character will overwrite it." % slot
	else:
		_notice = ""
	_mode = "new_name"
	_refresh()


func _confirm_new(char_name: String) -> void:
	SaveService.new_game_in_slot(_pending_slot, char_name)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _load_slot(slot: int) -> void:
	if SaveService.load_slot(slot):
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
		return
	_notice = SaveService.load_failure_message()
	_refresh()


func _exit_game() -> void:
	get_tree().quit()


func current_mode() -> String:
	return _mode
