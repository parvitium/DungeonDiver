extends Control

var _confirming_abandon: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func refresh() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var sheet := ThemeFactory.centered_sheet(self, Vector2(340, 300))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_top = 12
	box.offset_right = -16
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 8)
	sheet.add_child(box)
	box.add_child(ThemeFactory.label("Paused", 28, Color(0.95, 0.82, 0.45)))
	box.add_child(_btn("Resume", _resume, true))
	box.add_child(_btn("Settings", _settings))
	box.add_child(_btn("Save", _save))
	if _confirming_abandon:
		box.add_child(ThemeFactory.label("Leave the dungeon? The last save is kept.", 14, Color(0.95, 0.55, 0.4), true))
		box.add_child(_btn("Confirm abandon", _abandon))
		box.add_child(_btn("Cancel", _cancel_abandon))
	else:
		box.add_child(_btn("Abandon dungeon", _ask_abandon))
	var settings := SettingsPanel.new()
	settings.visible = false
	settings.name = "Settings"
	settings.closed.connect(func() -> void: visible = true)
	add_child(settings)


func _btn(text: String, cb: Callable, primary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40 if primary else 34)
	ThemeFactory.apply_button(btn)
	if primary:
		btn.add_theme_color_override("font_color", Color(1.0, 0.93, 0.62))
	btn.pressed.connect(cb)
	return btn


func _resume() -> void:
	_confirming_abandon = false
	visible = false
	GameSession.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _save() -> void:
	if SaveService.save_game():
		GameSession.log_message.emit("Progress saved.", Color(0.7, 0.9, 0.6))


func _ask_abandon() -> void:
	_confirming_abandon = true
	refresh()


func _cancel_abandon() -> void:
	_confirming_abandon = false
	refresh()


func _abandon() -> void:
	_confirming_abandon = false
	GameSession.end_run(false)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _settings() -> void:
	var panel := get_node_or_null("Settings")
	if panel:
		panel.visible = true
