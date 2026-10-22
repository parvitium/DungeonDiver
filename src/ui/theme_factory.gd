class_name ThemeFactory
extends RefCounted


static func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	box.border_color = Color(0.72, 0.58, 0.28, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func button() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.22, 0.16, 0.1, 0.95)
	box.border_color = Color(0.8, 0.65, 0.3)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func apply_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", button())
	var hover := button()
	hover.bg_color = Color(0.34, 0.24, 0.12, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	btn.focus_mode = Control.FOCUS_NONE


static func label(text: String, size: int = 16, color: Color = Color(0.93, 0.88, 0.75)) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl
