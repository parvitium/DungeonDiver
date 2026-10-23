class_name SettingsPanel
extends Control


signal closed

var _quality_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.01, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.panel())
	panel.custom_minimum_size = Vector2(540, 460)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 22
	root.offset_top = 18
	root.offset_right = -22
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	root.add_child(ThemeFactory.label("Settings", 28, Color(0.96, 0.84, 0.48)))
	root.add_child(ThemeFactory.label("Applies immediately and writes user://dungeondiver_settings.json.", 13, Color(0.7, 0.64, 0.52), true))

	_slider_row(root, "Mouse sensitivity", SettingsService.mouse_sensitivity, 0.2, 3.0, func(v: float) -> void: SettingsService.set_mouse_sensitivity(v))
	_slider_row(root, "Field of view", SettingsService.fov, 50.0, 110.0, func(v: float) -> void: SettingsService.set_fov(v))
	_slider_row(root, "Volume", SettingsService.master_volume, 0.0, 1.0, func(v: float) -> void: SettingsService.set_master_volume(v))

	root.add_child(ThemeFactory.label("Graphics quality", 16))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	root.add_child(qrow)
	_quality_label = ThemeFactory.label(SettingsService.graphics_quality.capitalize(), 16, Color(0.95, 0.82, 0.5))
	_quality_label.custom_minimum_size = Vector2(80, 0)
	qrow.add_child(_quality_label)
	for q in SettingsService.QUALITIES:
		var btn := Button.new()
		btn.text = q.capitalize()
		ThemeFactory.apply_button(btn)
		btn.pressed.connect(_set_quality.bind(q))
		qrow.add_child(btn)

	var back := Button.new()
	back.text = "Back"
	ThemeFactory.apply_button(back)
	back.pressed.connect(_close)
	root.add_child(back)


func _slider_row(parent: Control, title: String, value: float, lo: float, hi: float, cb: Callable) -> void:
	parent.add_child(ThemeFactory.label(title, 16))
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(460, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(cb)
	parent.add_child(slider)


func _set_quality(quality: String) -> void:
	SettingsService.set_graphics_quality(quality)
	if _quality_label:
		_quality_label.text = quality.capitalize()


func _close() -> void:
	visible = false
	closed.emit()
