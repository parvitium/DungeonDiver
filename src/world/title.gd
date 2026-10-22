extends Node3D
## Cinematic title: torch-lit hall, slow camera, logo, and the main menu.

var _camera: Camera3D
var _cam_origin: Vector3 = Vector3(0.0, 1.62, 5.8)
var _menu: Control
var _settings: SettingsPanel
var _bestiary: Control
var _t: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSession.ui_open = true
	if SaveService.has_save():
		SaveService.load_game()
	_build_hall()
	_build_silhouette()
	_build_camera()
	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	if _camera == null:
		return
	var sway := Vector3(sin(_t * 0.16) * 0.22, sin(_t * 0.11) * 0.08, -_t * 0.12)
	_camera.position = _cam_origin + sway
	_camera.look_at(Vector3(sin(_t * 0.1) * 0.25, 1.25, -16.0 + sin(_t * 0.07) * 0.4))


func _build_hall() -> void:
	var world := WorldEnvironment.new()
	world.environment = VisualLook.make_title_environment()
	add_child(world)
	var theme := &"crypt"
	for i in 4:
		var origin := Vector3(0, 0, -float(i) * DD.ROOM_SIZE)
		var floor := DungeonKit.slab(Vector3(DD.ROOM_SIZE, 0.35, DD.ROOM_SIZE), PBRLibrary.floor_mat(theme), "floor", 1.0)
		floor.position = origin + Vector3(0, -0.175, 0)
		add_child(floor)
		var ceiling := DungeonKit.slab(Vector3(DD.ROOM_SIZE, 0.3, DD.ROOM_SIZE), PBRLibrary.ceiling(theme), "ceiling", 1.0)
		ceiling.position = origin + Vector3(0, DD.WALL_HEIGHT + 0.15, 0)
		add_child(ceiling)
		var doors := {"n": i < 3, "s": i > 0, "e": false, "w": false}
		var half := DD.ROOM_SIZE * 0.5
		DungeonKit.wall_run(self, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, -half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(doors["n"]), theme, "n")
		DungeonKit.wall_run(self, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(doors["s"]), theme, "s")
		DungeonKit.wall_run(self, origin + Vector3(half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), false, theme, "e")
		DungeonKit.wall_run(self, origin + Vector3(-half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), false, theme, "w")
		DungeonKit.pillars(self, origin, theme)
		DungeonKit.beams(self, origin, theme)
		DungeonKit.torch_at(self, origin + Vector3(-5.8, 2.2, -2.4), i == 0)
		DungeonKit.torch_at(self, origin + Vector3(5.8, 2.2, 2.1), false)
		var fill := OmniLight3D.new()
		fill.position = origin + Vector3(0, 2.5, 0)
		fill.light_color = Color(1.0, 0.7, 0.4)
		fill.light_energy = 6.0
		fill.omni_range = 13.0
		VisualLook.configure_omni(fill, false)
		add_child(fill)
		if i == 1:
			DungeonKit.place_prop(self, origin + Vector3(-3.6, 0, 3.2), "barrel", theme)
			DungeonKit.place_prop(self, origin + Vector3(3.8, 0, -2.5), "bones", theme)
		if i == 2:
			DungeonKit.place_prop(self, origin + Vector3(0, 2.5, -4.2), "chain", theme)


func _build_silhouette() -> void:
	var mob := Monster.new()
	var def: MonsterDef = ContentDB.get_monster(&"lich")
	add_child(mob)
	mob.setup(def, 1)
	mob.set_physics_process(false)
	mob.global_position = Vector3(0.15, 0.05, -22.5)
	mob.rotation_degrees = Vector3(0, 180, 0)
	var backlight := OmniLight3D.new()
	backlight.position = Vector3(0, 2.6, -25.5)
	backlight.light_color = Color(0.62, 0.28, 0.95)
	backlight.light_energy = 8.0
	backlight.omni_range = 11.0
	backlight.shadow_enabled = false
	add_child(backlight)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 1.8, -20.5)
	rim.light_color = Color(1.0, 0.55, 0.25)
	rim.light_energy = 2.8
	rim.omni_range = 6.0
	add_child(rim)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.position = _cam_origin
	add_child(_camera)
	_camera.look_at(Vector3(0, 1.25, -16))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_menu)

	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0, 0, 0, 0.0)
	_menu.add_child(vignette)
	var grad := StyleBoxFlat.new()
	grad.bg_color = Color(0.02, 0.01, 0.01, 0.55)
	var wash := Panel.new()
	wash.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	wash.offset_right = 520
	wash.add_theme_stylebox_override("panel", grad)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(wash)

	var col := VBoxContainer.new()
	col.position = Vector2(56, 72)
	col.custom_minimum_size = Vector2(400, 0)
	col.add_theme_constant_override("separation", 10)
	_menu.add_child(col)

	var kicker := ThemeFactory.label("A FIRST-PERSON DUNGEON CRAWLER", 13, Color(0.78, 0.62, 0.38))
	col.add_child(kicker)
	var title := ThemeFactory.label("DUNGEON DIVER", 54, Color(0.98, 0.86, 0.52))
	col.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(0.82, 0.64, 0.28, 0.85)
	rule.custom_minimum_size = Vector2(280, 2)
	col.add_child(rule)
	col.add_child(ThemeFactory.label("Conquer every hall. Catalog every beast.", 16, Color(0.8, 0.72, 0.58)))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	buttons.add_child(_menu_btn("Play", _play))
	var cont := _menu_btn("Continue", _continue)
	cont.disabled = not SaveService.has_save()
	buttons.add_child(cont)
	buttons.add_child(_menu_btn("Bestiary", _open_bestiary))
	buttons.add_child(_menu_btn("Settings", _open_settings))
	buttons.add_child(_menu_btn("Quit", _quit))

	_bestiary = preload("res://src/ui/bestiary_panel.gd").new()
	_bestiary.visible = false
	_menu.add_child(_bestiary)
	_settings = SettingsPanel.new()
	_settings.name = "Settings"
	_settings.visible = false
	_menu.add_child(_settings)


func _menu_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 44)
	ThemeFactory.apply_menu_button(btn)
	btn.pressed.connect(cb)
	return btn


func _play() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _continue() -> void:
	if SaveService.has_save():
		SaveService.load_game()
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _open_bestiary() -> void:
	_bestiary.visible = not _bestiary.visible
	_settings.visible = false
	if _bestiary.visible:
		_bestiary.refresh()


func _open_settings() -> void:
	_settings.visible = not _settings.visible
	_bestiary.visible = false


func _quit() -> void:
	get_tree().quit()
