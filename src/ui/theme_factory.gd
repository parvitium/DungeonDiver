class_name ThemeFactory
extends RefCounted


static func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.055, 0.04, 0.94)
	box.border_color = Color(0.78, 0.6, 0.28, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func button() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.18, 0.12, 0.07, 0.96)
	box.border_color = Color(0.72, 0.55, 0.26)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box


static func apply_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", button())
	var hover := button()
	hover.bg_color = Color(0.36, 0.24, 0.1, 0.98)
	hover.border_color = Color(0.95, 0.78, 0.38)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := button()
	pressed.bg_color = Color(0.12, 0.08, 0.04, 0.98)
	pressed.border_color = Color(0.55, 0.4, 0.18)
	pressed.content_margin_top = 9
	pressed.content_margin_bottom = 5
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := button()
	disabled.bg_color = Color(0.1, 0.09, 0.08, 0.7)
	disabled.border_color = Color(0.28, 0.24, 0.18, 0.6)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72))
	btn.add_theme_color_override("font_pressed_color", Color(0.78, 0.68, 0.45))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.4, 0.32))
	btn.focus_mode = Control.FOCUS_NONE


static func apply_menu_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.05, 0.03, 0.55)
	normal.border_color = Color(0.7, 0.52, 0.22, 0.35)
	normal.border_width_left = 3
	normal.content_margin_left = 18
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(0.32, 0.18, 0.06, 0.88)
	hover.border_color = Color(0.96, 0.78, 0.36, 1.0)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.07, 0.03, 0.95)
	pressed.border_color = Color(0.6, 0.42, 0.16)
	pressed.content_margin_top = 12
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.06, 0.05, 0.04, 0.4)
	disabled.border_color = Color(0.25, 0.22, 0.16, 0.4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.68))
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.62, 0.38))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.36, 0.28))
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT


static func centered_sheet(parent: Control, min_size: Vector2) -> Panel:
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := Panel.new()
	panel.name = "Sheet"
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", panel())
	center.add_child(panel)
	return panel


static func label(text: String, size: int = 16, color: Color = Color(0.93, 0.88, 0.75), wrap: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return lbl
