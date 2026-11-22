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


static func apply_button(btn: Button, selected: bool = false) -> void:
	var normal := button()
	if selected:
		normal.bg_color = Color(0.42, 0.3, 0.12, 0.98)
		normal.border_color = Color(0.95, 0.82, 0.42)
		normal.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := button()
	hover.bg_color = Color(0.34, 0.24, 0.12, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if btn.custom_minimum_size.y < 36.0:
		btn.custom_minimum_size.y = 36.0


static func label(text: String, size: int = 16, color: Color = Color(0.93, 0.88, 0.75), wrap: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	lbl.clip_text = false
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


static func close_button(cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = "X"
	btn.tooltip_text = "Close"
	apply_button(btn)
	btn.custom_minimum_size = Vector2(36, 32)
	btn.pressed.connect(cb)
	return btn


## Full-rect overlay + centered panel clamped to the viewport.
static func mount_modal(host: Control, opaque: bool = true, frac_w: float = 0.9, frac_h: float = 0.88) -> Panel:
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.grow_horizontal = Control.GROW_DIRECTION_BOTH
	host.grow_vertical = Control.GROW_DIRECTION_BOTH
	host.clip_contents = true
	var dim := ColorRect.new()
	dim.name = "ModalDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.025, 1.0) if opaque else Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(dim)
	var center := CenterContainer.new()
	center.name = "ModalCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(center)
	var style := panel()
	var dialog := Panel.new()
	dialog.name = "PackPanel"
	dialog.clip_contents = true
	dialog.add_theme_stylebox_override("panel", style)
	center.add_child(dialog)
	fit_modal_panel(host, dialog, frac_w, frac_h)
	return dialog


static func fit_modal_panel(host: Control, panel: Control, frac_w: float = 0.9, frac_h: float = 0.88) -> void:
	var vp := Vector2.ZERO
	if host.is_inside_tree():
		vp = host.get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		vp = host.size
	if vp.x < 8.0 or vp.y < 8.0:
		vp = Vector2(1280, 720)
	var pad := 24.0
	var w := clampf(vp.x * frac_w, 480.0, maxf(160.0, vp.x - pad))
	var h := clampf(vp.y * frac_h, 360.0, maxf(160.0, vp.y - pad))
	panel.custom_minimum_size = Vector2(w, h)
	panel.size = Vector2(w, h)
