extends Control
## Graphics, audio, look, fullscreen, and key rebinding. Used from the menu and pause.

signal closed

var return_to: Control = null
var _waiting_action: String = ""
var _status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	refresh()


func present(from: Control = null) -> void:
	return_to = from
	visible = true
	_waiting_action = ""
	refresh()


func close() -> void:
	visible = false
	_waiting_action = ""
	if return_to:
		return_to.visible = true
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _waiting_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			_bind(_waiting_action, event)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_bind(_waiting_action, event)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	var panel := ThemeFactory.mount_modal(self, true, 0.72, 0.9)
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 18)
	inner.add_theme_constant_override("margin_top", 14)
	inner.add_theme_constant_override("margin_right", 18)
	inner.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(inner)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	inner.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := ThemeFactory.label("Settings", 28, Color(0.95, 0.82, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(ThemeFactory.close_button(close))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	box.add_child(ThemeFactory.label("Graphics", 18, Color(0.95, 0.82, 0.45)))
	var full := CheckBox.new()
	full.text = "Fullscreen"
	full.button_pressed = GameSession.game_settings.fullscreen
	full.focus_mode = Control.FOCUS_NONE
	full.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	full.toggled.connect(func(on: bool) -> void:
		GameSession.game_settings.fullscreen = on
		GameSession.game_settings.apply_all()
	)
	box.add_child(full)
	var fxaa := CheckBox.new()
	fxaa.text = "FXAA"
	fxaa.button_pressed = GameSession.game_settings.fxaa
	fxaa.focus_mode = Control.FOCUS_NONE
	fxaa.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	fxaa.toggled.connect(func(on: bool) -> void:
		GameSession.game_settings.fxaa = on
		GameSession.game_settings.apply_all()
	)
	box.add_child(fxaa)
	var msaa_row := HBoxContainer.new()
	msaa_row.add_theme_constant_override("separation", 10)
	box.add_child(msaa_row)
	msaa_row.add_child(ThemeFactory.label("MSAA", 14))
	var msaa := OptionButton.new()
	msaa.add_item("Off", 0)
	msaa.add_item("2x", 1)
	msaa.add_item("4x", 2)
	msaa.add_item("8x", 3)
	msaa.select(GameSession.game_settings.msaa)
	msaa.item_selected.connect(func(idx: int) -> void:
		GameSession.game_settings.msaa = idx
		GameSession.game_settings.apply_all()
	)
	msaa_row.add_child(msaa)

	box.add_child(ThemeFactory.label("Audio", 18, Color(0.95, 0.82, 0.45)))
	box.add_child(_volume_row("Music", GameSession.game_settings.music_volume, func(v: float) -> void:
		GameSession.game_settings.music_volume = v
		GameSession.game_settings.apply_all()
	))
	box.add_child(_volume_row("SFX", GameSession.game_settings.sfx_volume, func(v: float) -> void:
		GameSession.game_settings.sfx_volume = v
		GameSession.game_settings.apply_all()
	))

	box.add_child(ThemeFactory.label("Mouse", 18, Color(0.95, 0.82, 0.45)))
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

	box.add_child(ThemeFactory.label("Key bindings", 18, Color(0.95, 0.82, 0.45)))
	_status = ThemeFactory.label("Click a bind, then press a key or mouse button.", 14, Color(0.75, 0.7, 0.55))
	box.add_child(_status)
	for action in GameSettings.BINDABLE:
		box.add_child(_bind_row(action))


func _volume_row(label: String, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := ThemeFactory.label(label, 14)
	name.custom_minimum_size = Vector2(110, 0)
	row.add_child(name)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(160, 24)
	slider.value_changed.connect(cb)
	row.add_child(slider)
	return row


func _bind_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name := ThemeFactory.label(GameSettings.action_label(action), 14)
	name.custom_minimum_size = Vector2(160, 0)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var btn := Button.new()
	btn.text = "Press a key…" if _waiting_action == action else GameSettings.current_key_name(action)
	ThemeFactory.apply_button(btn, _waiting_action == action)
	btn.custom_minimum_size = Vector2(180, 36)
	btn.pressed.connect(func() -> void:
		_waiting_action = action
		refresh()
	)
	row.add_child(btn)
	return row


func _bind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		_waiting_action = ""
		refresh()
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	if event is InputEventKey:
		GameSession.game_settings.keybinds[action] = int((event as InputEventKey).physical_keycode)
	GameSession.game_settings.apply_all()
	_waiting_action = ""
	if _status:
		_status.text = "Rebound %s." % GameSettings.action_label(action)
	refresh()
