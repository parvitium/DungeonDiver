extends Control

## HUD pause recaptures the mouse even when GameSession.run is briefly null in tests.
var dungeon_context: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		_resume()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	var panel := ThemeFactory.mount_modal(self, false, 0.42, 0.72)
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 18)
	inner.add_theme_constant_override("margin_top", 16)
	inner.add_theme_constant_override("margin_right", 18)
	inner.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	inner.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := ThemeFactory.label("Paused", 28, Color(0.95, 0.82, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(ThemeFactory.close_button(_resume))
	box.add_child(_btn("Resume", _resume))
	box.add_child(_btn("Settings", _open_settings))
	if not _in_dungeon():
		box.add_child(_btn("Save", _save))
	box.add_child(_btn("Main Menu", _main_menu))


func _btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	return btn


func _in_dungeon() -> bool:
	return dungeon_context or GameSession.run != null


func _resume() -> void:
	visible = false
	if _in_dungeon():
		GameSession.ui_open = false
		if is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.paused = false
		MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	else:
		GameSession.ui_open = true
		if is_inside_tree():
			var tree := get_tree()
			if tree:
				tree.paused = false
		MouseCapture.apply(MouseCapture.Context.HUB)


func _open_settings() -> void:
	visible = false
	var host := get_parent()
	if host == null:
		return
	var settings := host.get_node_or_null("Settings")
	if settings and settings.has_method("present"):
		settings.present(self)


func _save() -> void:
	if SaveService.save_active():
		GameSession.log_message.emit("Progress saved.", Color(0.7, 0.9, 0.6))


func _main_menu() -> void:
	visible = false
	if GameSession.run != null:
		GameSession.go_to_main_menu()
		return
	SaveService.save_active()
	GameSession.go_to_main_menu()
