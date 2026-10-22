extends Control


func _ready() -> void:
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
	box.position = Vector2(-140, -90)
	box.custom_minimum_size = Vector2(280, 0)
	add_child(box)
	box.add_child(ThemeFactory.label("Paused", 28, Color(0.95, 0.82, 0.45)))
	box.add_child(_btn("Resume", _resume))
	box.add_child(_btn("Settings", _settings))
	box.add_child(_btn("Save", _save))
	box.add_child(_btn("Abandon dungeon", _abandon))
	var settings := SettingsPanel.new()
	settings.visible = false
	settings.name = "Settings"
	settings.closed.connect(func() -> void: visible = true)
	add_child(settings)


func _btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	return btn


func _resume() -> void:
	visible = false
	GameSession.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _save() -> void:
	if SaveService.save_game():
		GameSession.log_message.emit("Progress saved.", Color(0.7, 0.9, 0.6))


func _abandon() -> void:
	GameSession.end_run(false)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _settings() -> void:
	var panel := get_node_or_null("Settings")
	if panel:
		panel.visible = true

