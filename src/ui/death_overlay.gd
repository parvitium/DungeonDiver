extends CanvasLayer
## Fade-to-black death modal. Retry restarts this dungeon; Menu returns to hub.

signal retry_pressed
signal menu_pressed

var _fade: ColorRect
var _modal: Panel
var _title: Label
var _stats: Label
var _lost: Label
var _retry: Button
var _menu: Button
var _shown: bool = false


func _ready() -> void:
	name = "DeathOverlay"
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_showing() -> bool:
	return _shown


func title_text() -> String:
	return _title.text if _title else ""


func stats_text() -> String:
	return _stats.text if _stats else ""


func lost_text() -> String:
	return _lost.text if _lost else ""


func present(info: Dictionary, instant: bool = false) -> void:
	if _fade == null:
		_build()
	_shown = true
	visible = true
	GameSession.ui_open = true
	MouseCapture.apply(MouseCapture.Context.DUNGEON_UI)
	var tree := get_tree()
	if tree:
		tree.paused = true
	var depth := int(info.get("depth", 1))
	var kills := int(info.get("kills", 0))
	var dungeon := str(info.get("dungeon", "the dungeon"))
	var lost := int(info.get("lost", 0))
	_stats.text = "%s  ·  Depth %d  ·  %d slain" % [dungeon, depth, kills]
	if _lost:
		_lost.text = "Lost %d items found this run" % lost
	_modal.visible = instant
	if instant:
		_fade.color = Color(0, 0, 0, 0.92)
		_show_modal()
		return
	_fade.color = Color(0, 0, 0, 0)
	_modal.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", 0.92, 1.5)
	tween.tween_callback(_show_modal)


func press_retry() -> void:
	_on_retry()


func press_menu() -> void:
	_on_menu()


func _show_modal() -> void:
	_modal.visible = true
	_modal.modulate.a = 1.0


func _build() -> void:
	if _fade != null:
		return
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fade)

	var host := Control.new()
	host.name = "DeathHost"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	_modal = ThemeFactory.mount_modal(host, true, 0.46, 0.52)
	_modal.visible = false

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 22
	box.offset_top = 18
	box.offset_right = -22
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 12)
	_modal.add_child(box)

	_title = ThemeFactory.label("You Died", 36, Color(0.95, 0.82, 0.42))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_stats = ThemeFactory.label("", 16, Color(0.8, 0.74, 0.6))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats)
	_lost = ThemeFactory.label("", 16, Color(0.95, 0.55, 0.4))
	_lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lost)

	_retry = Button.new()
	_retry.text = "Retry"
	ThemeFactory.apply_button(_retry)
	_retry.pressed.connect(_on_retry)
	box.add_child(_retry)

	_menu = Button.new()
	_menu.text = "Main Menu"
	ThemeFactory.apply_button(_menu)
	_menu.pressed.connect(_on_menu)
	box.add_child(_menu)


func _on_retry() -> void:
	_shown = false
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.paused = false
	GameSession.ui_open = false
	retry_pressed.emit()


func _on_menu() -> void:
	_shown = false
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.paused = false
	GameSession.ui_open = false
	MouseCapture.apply(MouseCapture.Context.HUB)
	menu_pressed.emit()
