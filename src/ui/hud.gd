extends CanvasLayer

var _hp_bar: ProgressBar
var _sta_bar: ProgressBar
var _hp_label: Label
var _sta_label: Label
var _log: RichTextLabel
var _prompt: Label
var _title: Label
var _inv_panel: Control
var _bestiary_panel: Control
var _pause_panel: Control
var _player: Player


func _ready() -> void:
	layer = 10
	_build()
	if not GameSession.log_message.is_connected(_on_log):
		GameSession.log_message.connect(_on_log)
	if not GameSession.profile_changed.is_connected(_refresh_overlay_stats):
		GameSession.profile_changed.connect(_refresh_overlay_stats)


func bind_player(player: Player) -> void:
	_player = player
	if not player.vitals_changed.is_connected(_on_vitals):
		player.vitals_changed.connect(_on_vitals)
	if not player.prompt_changed.is_connected(_on_prompt):
		player.prompt_changed.connect(_on_prompt)
	_on_vitals()
	_refresh_header()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_title = ThemeFactory.label("", 18, Color(0.9, 0.8, 0.5))
	_title.position = Vector2(24, 16)
	_title.size = Vector2(720, 28)
	root.add_child(_title)

	var bars := VBoxContainer.new()
	bars.position = Vector2(24, 48)
	bars.custom_minimum_size = Vector2(280, 0)
	root.add_child(bars)
	_hp_label = ThemeFactory.label("Health", 14)
	_hp_bar = _bar(Color(0.75, 0.15, 0.15))
	_sta_label = ThemeFactory.label("Stamina", 14)
	_sta_bar = _bar(Color(0.2, 0.55, 0.85))
	bars.add_child(_hp_label)
	bars.add_child(_hp_bar)
	bars.add_child(_sta_label)
	bars.add_child(_sta_bar)

	var cross := ColorRect.new()
	cross.color = Color(0.95, 0.9, 0.75, 0.85)
	cross.size = Vector2(10, 2)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-5, -1)
	root.add_child(cross)
	var cross2 := ColorRect.new()
	cross2.color = Color(0.95, 0.9, 0.75, 0.85)
	cross2.size = Vector2(2, 10)
	cross2.set_anchors_preset(Control.PRESET_CENTER)
	cross2.position = Vector2(-1, -5)
	root.add_child(cross2)

	_prompt = ThemeFactory.label("", 18, Color(1, 0.92, 0.65))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-220, -90)
	_prompt.size = Vector2(440, 32)
	root.add_child(_prompt)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log.position = Vector2(24, -170)
	_log.size = Vector2(420, 120)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 14)
	root.add_child(_log)

	var hint := ThemeFactory.label("LMB melee  RMB block  F ember bolt  E use  I pack  B bestiary  Esc pause", 13, Color(0.7, 0.65, 0.55))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-620, -36)
	hint.size = Vector2(600, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	_inv_panel = preload("res://src/ui/inventory_panel.gd").new()
	_inv_panel.visible = false
	root.add_child(_inv_panel)
	_bestiary_panel = preload("res://src/ui/bestiary_panel.gd").new()
	_bestiary_panel.visible = false
	root.add_child(_bestiary_panel)
	_pause_panel = preload("res://src/ui/pause_panel.gd").new()
	_pause_panel.visible = false
	root.add_child(_pause_panel)


func _bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, 18)
	bar.show_percentage = false
	bar.max_value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_inventory"):
		_toggle(_inv_panel)
	elif Input.is_action_just_pressed("toggle_bestiary"):
		_toggle(_bestiary_panel)
	elif Input.is_action_just_pressed("pause_menu"):
		if _inv_panel.visible or _bestiary_panel.visible:
			_close_all()
		else:
			_toggle(_pause_panel)


func _toggle(panel: Control) -> void:
	var opening := not panel.visible
	_close_all()
	if opening:
		panel.visible = true
		if panel.has_method("refresh"):
			panel.refresh()
		GameSession.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_restore_capture()


func _close_all() -> void:
	_inv_panel.visible = false
	_bestiary_panel.visible = false
	_pause_panel.visible = false
	_restore_capture()


func _restore_capture() -> void:
	GameSession.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_vitals() -> void:
	if _player == null:
		return
	var stats := GameSession.profile.total_stats()
	_hp_bar.max_value = stats.max_health
	_sta_bar.max_value = stats.max_stamina
	_hp_bar.value = _player.health
	_sta_bar.value = _player.stamina
	_hp_label.text = "Health  %d / %d" % [int(_player.health), int(stats.max_health)]
	_sta_label.text = "Stamina  %d / %d" % [int(_player.stamina), int(stats.max_stamina)]


func _refresh_overlay_stats() -> void:
	_on_vitals()
	_refresh_header()


func _refresh_header() -> void:
	if GameSession.run == null:
		_title.text = "DungeonDiver"
		return
	var def: DungeonTypeDef = ContentDB.get_dungeon(GameSession.run.dungeon_id)
	var name := def.display_name if def else String(GameSession.run.dungeon_id)
	_title.text = "%s  ·  Depth %d  ·  Tier %d" % [name, GameSession.run.depth, GameSession.run.effective_tier]


func _on_prompt(text: String) -> void:
	_prompt.text = text


func _on_log(text: String, color: Color) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
