extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	refresh()


func refresh() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-160, -160)
	box.custom_minimum_size = Vector2(320, 0)
	add_child(box)
	box.add_child(ThemeFactory.label("Paused", 28, Color(0.95, 0.82, 0.45)))
	box.add_child(_btn("Resume", _resume))
	box.add_child(_btn("Save", _save))
	box.add_child(_btn("Abandon dungeon", _abandon))
	_add_look_settings(box)


func _btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	return btn


func _add_look_settings(box: VBoxContainer) -> void:
	box.add_child(ThemeFactory.label("Look", 18, Color(0.85, 0.75, 0.5)))
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 8)
	box.add_child(sens_row)
	var sens_label := ThemeFactory.label("Sensitivity", 14)
	sens_label.custom_minimum_size = Vector2(110, 0)
	sens_row.add_child(sens_label)
	var slider := HSlider.new()
	slider.min_value = LookSettings.MIN_SENSITIVITY
	slider.max_value = LookSettings.MAX_SENSITIVITY
	slider.step = 0.05
	slider.value = GameSession.look_settings.sensitivity
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(160, 24)
	slider.value_changed.connect(func(v: float) -> void: GameSession.look_settings.set_sensitivity(v))
	sens_row.add_child(slider)
	var invert := CheckBox.new()
	invert.text = "Invert Y"
	invert.button_pressed = GameSession.look_settings.invert_y
	invert.focus_mode = Control.FOCUS_NONE
	invert.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	invert.toggled.connect(func(on: bool) -> void: GameSession.look_settings.set_invert_y(on))
	box.add_child(invert)


func _resume() -> void:
	visible = false
	GameSession.ui_open = false
	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)


func _save() -> void:
	if SaveService.save_game():
		GameSession.log_message.emit("Progress saved.", Color(0.7, 0.9, 0.6))


func _abandon() -> void:
	GameSession.end_run(false)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
