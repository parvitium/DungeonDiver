extends CanvasLayer

var _hp_bar: ProgressBar
var _hp_trail: ProgressBar
var _sta_bar: ProgressBar
var _hp_label: Label
var _sta_label: Label
var _log: RichTextLabel
var _prompt: Label
var _title: Label
var _gold: Label
var _inv_panel: Control
var _bestiary_panel: Control
var _pause_panel: Control
var _settings_panel: Control
var _player: Player
var _built: bool = false
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _dir_arrow: Polygon2D
var _dir_wrap: Control
var _vignette_strength: float = 0.0
var _dir_timer: float = 0.0
var _trail_value: float = 100.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if player.has_signal("took_hit") and not player.took_hit.is_connected(_on_took_hit):
		player.took_hit.connect(_on_took_hit)
	_on_vitals()
	_refresh_header()


func _build() -> void:
	if _built:
		return
	_built = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV;
	float d = length((uv - vec2(0.5)) * vec2(1.6, 1.0));
	float v = smoothstep(0.28, 0.92, d);
	COLOR = vec4(0.72, 0.04, 0.05, v * intensity);
}
"""
	_vignette_mat.shader = sh
	_vignette.material = _vignette_mat
	root.add_child(_vignette)

	_title = ThemeFactory.label("", 18, Color(0.9, 0.8, 0.5))
	_title.position = Vector2(24, 16)
	_ignore_mouse(_title)
	root.add_child(_title)
	_gold = ThemeFactory.label("", 16, Color(0.95, 0.82, 0.35))
	_gold.position = Vector2(24, 36)
	_ignore_mouse(_gold)
	root.add_child(_gold)

	var bars := VBoxContainer.new()
	bars.position = Vector2(24, 60)
	bars.custom_minimum_size = Vector2(280, 0)
	_ignore_mouse(bars)
	root.add_child(bars)
	_hp_label = ThemeFactory.label("Health", 14)
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(280, 18)
	_hp_trail = _bar(Color(0.85, 0.45, 0.12))
	_hp_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_bar = _bar(Color(0.75, 0.15, 0.15))
	_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_stack.add_child(_hp_trail)
	hp_stack.add_child(_hp_bar)
	_sta_label = ThemeFactory.label("Stamina", 14)
	_sta_bar = _bar(Color(0.2, 0.55, 0.85))
	_ignore_mouse(_hp_label)
	_ignore_mouse(hp_stack)
	_ignore_mouse(_sta_label)
	_ignore_mouse(_sta_bar)
	bars.add_child(_hp_label)
	bars.add_child(hp_stack)
	bars.add_child(_sta_label)
	bars.add_child(_sta_bar)

	var cross := ColorRect.new()
	cross.color = Color(0.95, 0.9, 0.75, 0.85)
	cross.size = Vector2(10, 2)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-5, -1)
	_ignore_mouse(cross)
	root.add_child(cross)
	var cross2 := ColorRect.new()
	cross2.color = Color(0.95, 0.9, 0.75, 0.85)
	cross2.size = Vector2(2, 10)
	cross2.set_anchors_preset(Control.PRESET_CENTER)
	cross2.position = Vector2(-1, -5)
	_ignore_mouse(cross2)
	root.add_child(cross2)

	_dir_wrap = Control.new()
	_dir_wrap.set_anchors_preset(Control.PRESET_CENTER)
	_dir_wrap.position = Vector2(0, 0)
	_dir_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dir_wrap.visible = false
	root.add_child(_dir_wrap)
	_dir_arrow = Polygon2D.new()
	_dir_arrow.color = Color(0.95, 0.2, 0.15, 0.9)
	_dir_arrow.polygon = PackedVector2Array([
		Vector2(0, -78), Vector2(12, -54), Vector2(-12, -54)
	])
	_dir_wrap.add_child(_dir_arrow)

	_prompt = ThemeFactory.label("", 18, Color(1, 0.92, 0.65))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-220, -90)
	_prompt.size = Vector2(440, 32)
	_ignore_mouse(_prompt)
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

	var hint := ThemeFactory.label("LMB melee  RMB block  F ember bolt  E use  Tab/I pack  B bestiary  Esc pause", 13, Color(0.7, 0.65, 0.55))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-680, -36)
	hint.size = Vector2(660, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ignore_mouse(hint)
	root.add_child(hint)

	_inv_panel = preload("res://src/ui/inventory_panel.gd").new()
	_inv_panel.visible = false
	_inv_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_inv_panel)
	_bestiary_panel = preload("res://src/ui/bestiary_panel.gd").new()
	_bestiary_panel.visible = false
	_bestiary_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_bestiary_panel)
	_pause_panel = preload("res://src/ui/pause_panel.gd").new()
	_pause_panel.name = "Pause"
	_pause_panel.visible = false
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_panel.set("dungeon_context", true)
	root.add_child(_pause_panel)
	_settings_panel = preload("res://src/ui/settings_panel.gd").new()
	_settings_panel.name = "Settings"
	_settings_panel.visible = false
	_settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_settings_panel)


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


func _process(delta: float) -> void:
	if _vignette_mat:
		_vignette_strength = maxf(0.0, _vignette_strength - delta * 1.35)
		_vignette_mat.set_shader_parameter("intensity", _vignette_strength)
	if _dir_timer > 0.0:
		_dir_timer -= delta
		if _dir_timer <= 0.0 and _dir_wrap:
			_dir_wrap.visible = false
	if _hp_trail and _hp_bar:
		_trail_value = move_toward(_trail_value, _hp_bar.value, delta * 42.0)
		_hp_trail.value = _trail_value
	_sync_closed_panels()


func _sync_closed_panels() -> void:
	if _death_showing():
		return
	if _inv_panel and _inv_panel.visible:
		return
	if _bestiary_panel and _bestiary_panel.visible:
		return
	if _pause_panel and _pause_panel.visible:
		return
	if _settings_panel and _settings_panel.visible:
		return
	if GameSession.ui_open:
		_restore_capture()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if _inv_panel and _inv_panel.visible:
			_close_all()
		else:
			_toggle(_inv_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_bestiary"):
		if _bestiary_panel and _bestiary_panel.visible:
			_close_all()
		else:
			_toggle(_bestiary_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
		if _inv_panel.visible or _bestiary_panel.visible or (_settings_panel and _settings_panel.visible):
			_close_all()
		else:
			_toggle(_pause_panel)
		get_viewport().set_input_as_handled()


func _on_took_hit(amount: float, from: Vector3) -> void:
	_vignette_strength = clampf(0.28 + amount / 36.0, 0.28, 1.0)
	_dir_timer = 0.85
	if _dir_wrap:
		_dir_wrap.visible = true
		_dir_wrap.rotation = _hit_angle(from)
	if _hp_bar:
		_hp_trail.max_value = _hp_bar.max_value
		_trail_value = maxf(_trail_value, _hp_bar.value + amount)


func _hit_angle(from: Vector3) -> float:
	if _player == null:
		return 0.0
	var cam: Camera3D = _player.get_node_or_null("Head/Camera3D")
	if cam == null:
		return 0.0
	var to := from - cam.global_position
	var local := cam.global_transform.basis.inverse() * to
	return atan2(local.x, -local.z)


func _toggle(panel: Control) -> void:
	var opening := not panel.visible
	_close_all()
	if opening:
		panel.visible = true
		if panel.has_method("refresh"):
			panel.refresh()
		_set_ui_open(true)
	else:
		_restore_capture()


func _close_all() -> void:
	_inv_panel.visible = false
	_bestiary_panel.visible = false
	_pause_panel.visible = false
	if _settings_panel:
		_settings_panel.visible = false
	_restore_capture()


func _set_ui_open(open: bool) -> void:
	GameSession.ui_open = open
	if open:
		MouseCapture.apply(MouseCapture.Context.DUNGEON_UI)
	else:
		MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree and not _death_showing():
		tree.paused = open


func _death_showing() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var overlay := tree.root.find_child("DeathOverlay", true, false)
	return overlay != null and overlay.get("visible") == true and overlay.has_method("is_showing") and overlay.is_showing()


func _restore_capture() -> void:
	if _death_showing():
		GameSession.ui_open = true
		MouseCapture.apply(MouseCapture.Context.DUNGEON_UI)
		return
	_set_ui_open(false)


func _ignore_mouse(ctrl: Control) -> void:
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_inventory_open() -> bool:
	return _inv_panel != null and _inv_panel.visible


func is_bestiary_open() -> bool:
	return _bestiary_panel != null and _bestiary_panel.visible


func is_pause_open() -> bool:
	return _pause_panel != null and _pause_panel.visible


func open_inventory() -> void:
	_toggle(_inv_panel)


func open_bestiary() -> void:
	_toggle(_bestiary_panel)


func open_pause() -> void:
	_toggle(_pause_panel)


func close_panels() -> void:
	_close_all()


func pause_panel() -> Control:
	return _pause_panel


func _on_vitals() -> void:
	if _player == null:
		return
	var stats := GameSession.profile.total_stats()
	_hp_bar.max_value = stats.max_health
	_hp_trail.max_value = stats.max_health
	_sta_bar.max_value = stats.max_stamina
	_hp_bar.value = _player.health
	_sta_bar.value = _player.stamina
	if _trail_value < _player.health:
		_trail_value = _player.health
	_hp_label.text = "Health  %d / %d" % [int(_player.health), int(stats.max_health)]
	_sta_label.text = "Stamina  %d / %d" % [int(_player.stamina), int(stats.max_stamina)]


func _refresh_overlay_stats() -> void:
	_on_vitals()
	_refresh_header()


func _refresh_header() -> void:
	if _gold:
		_gold.text = "%d gold" % GameSession.profile.gold
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
