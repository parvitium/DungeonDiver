extends Node3D
## Cinematic title: torch-lit hall, slow camera, logo, and the main menu.

var _camera: Camera3D
var _cam_origin: Vector3 = Vector3(0.0, 1.55, 9.4)
var _menu: Control
var _settings: SettingsPanel
var _bestiary: Control
var _t: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSession.ui_open = true
	# Do not load here. Quarantining a bad save on the title screen would hide
	# the hub's corrupted-save notice. Continue/Play both go to the hub, which loads.
	_build_hall()
	_build_silhouette()
	_build_camera()
	_build_ui()


func _process(delta: float) -> void:
	_t += delta
	if _camera == null:
		return
	var sway := Vector3(sin(_t * 0.16) * 0.16, sin(_t * 0.11) * 0.06, -_t * 0.08)
	_camera.position = _cam_origin + sway
	_camera.look_at(Vector3(sin(_t * 0.1) * 0.18, 1.35, -12.0 + sin(_t * 0.07) * 0.3))


func _build_hall() -> void:
	var world := WorldEnvironment.new()
	world.environment = VisualLook.make_title_environment()
	add_child(world)
	var theme := &"crypt"
	var width := 7.2
	var length := 28.0
	var height := DD.WALL_HEIGHT
	var half_w := width * 0.5
	var origin := Vector3(0, 0, -4.0)
	var floor := DungeonKit.slab(Vector3(width, 0.35, length), PBRLibrary.floor_mat(theme), "floor", 1.0)
	floor.position = origin + Vector3(0, -0.175, 0)
	add_child(floor)
	var ceiling := DungeonKit.slab(Vector3(width, 0.3, length), PBRLibrary.ceiling(theme), "ceiling", 1.0)
	ceiling.position = origin + Vector3(0, height + 0.15, 0)
	add_child(ceiling)
	DungeonKit.wall_run(self, origin + Vector3(half_w, height * 0.5, 0), Vector3(DD.WALL_THICKNESS, height, length), false, theme, "e")
	DungeonKit.wall_run(self, origin + Vector3(-half_w, height * 0.5, 0), Vector3(DD.WALL_THICKNESS, height, length), false, theme, "w")
	DungeonKit.wall_run(self, origin + Vector3(0, height * 0.5, length * 0.5), Vector3(width, height, DD.WALL_THICKNESS), false, theme, "s")
	DungeonKit.wall_run(self, origin + Vector3(0, height * 0.5, -length * 0.5), Vector3(width, height, DD.WALL_THICKNESS), true, theme, "n")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 5:
		var z := 8.0 - float(i) * 5.2
		var authored := AssetLibrary.instance(AssetLibrary.kit_path("arch"))
		var arch: Node3D
		if authored:
			arch = authored
			arch.name = "HallArch"
			_paint_kit(arch, PBRLibrary.trim(theme))
		else:
			arch = MeshFactory.visual(MeshFactory.beveled_box(Vector3(width - 0.4, 0.28, 0.5), 0.04, 0.6), PBRLibrary.trim(theme), "HallArch")
		arch.position = Vector3(0, DD.DOOR_HEIGHT + 0.08, z)
		add_child(arch)
		var left_p := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.38, height, 0.38), 0.04, 0.7), PBRLibrary.trim(theme), "ColL")
		left_p.position = Vector3(-half_w + 0.55, height * 0.5, z)
		add_child(left_p)
		var right_p := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.38, height, 0.38), 0.04, 0.7), PBRLibrary.trim(theme), "ColR")
		right_p.position = Vector3(half_w - 0.55, height * 0.5, z)
		add_child(right_p)
		var beam := MeshFactory.visual(MeshFactory.beveled_box(Vector3(width - 0.7, 0.14, 0.18), 0.02, 0.8), PBRLibrary.wood(), "Beam")
		beam.position = Vector3(0, height - 0.22, z)
		add_child(beam)
		DungeonKit.torch_at(self, Vector3(-half_w + 0.42, 2.2, z + 1.4), i == 0 or i == 2)
		DungeonKit.torch_at(self, Vector3(half_w - 0.42, 2.2, z - 1.1), i == 1)
		if i % 2 == 0:
			DungeonKit.banner_at(self, Vector3(-half_w + 0.28, 2.35, z + 0.1), theme, Color(0.30, 0.10, 0.16), true)
		else:
			DungeonKit.banner_at(self, Vector3(half_w - 0.28, 2.35, z + 0.1), theme, Color(0.16, 0.12, 0.30), true)
	DungeonKit.place_prop(self, Vector3(-2.1, 0, 6.2), "barrel", theme)
	DungeonKit.place_prop(self, Vector3(2.2, 0, 3.4), "bones", theme)
	DungeonKit.place_prop(self, Vector3(-2.0, 0, -1.6), "bones", theme)
	DungeonKit.place_prop(self, Vector3(2.15, 2.4, -3.2), "chain", theme)
	DungeonKit.place_prop(self, Vector3(-2.25, 0, -6.8), "barrel", theme)
	DungeonKit.debris_at(self, Vector3(-2.3, 0, 4.8), theme, rng)
	DungeonKit.debris_at(self, Vector3(2.15, 0, -0.6), theme, rng)
	DungeonKit.debris_at(self, Vector3(-1.8, 0, -8.4), theme, rng)
	DungeonKit.puddle_at(self, Vector3(0.8, 0, 5.4), Vector3(1.3, 0.01, 0.7))
	DungeonKit.puddle_at(self, Vector3(-1.1, 0, 1.2), Vector3(0.9, 0.01, 0.5))
	DungeonKit.puddle_at(self, Vector3(0.4, 0, -5.6), Vector3(1.1, 0.01, 0.6))
	DungeonKit.fog_shaft(self, Vector3(0, 0.02, -14.8), 3.9)
	DungeonKit.hall_embers(self, Vector3(0, 1.4, 2.0))
	var bounce := DirectionalLight3D.new()
	bounce.name = "TitleFill"
	bounce.rotation_degrees = Vector3(-42, 12, 0)
	bounce.light_color = Color(0.55, 0.66, 0.82)
	bounce.light_energy = 0.42
	bounce.shadow_enabled = false
	add_child(bounce)
	for z in [8.0, 2.0, -4.0, -10.0]:
		var cool := OmniLight3D.new()
		cool.position = Vector3(0, 2.6, z)
		cool.light_color = Color(0.50, 0.62, 0.80)
		cool.light_energy = 1.15
		cool.omni_range = 7.5
		cool.omni_attenuation = 1.25
		VisualLook.configure_omni(cool, false)
		add_child(cool)


func _build_silhouette() -> void:
	var monster_script: GDScript = load("res://src/monster/monster.gd")
	var mob: Node = monster_script.new()
	var def: MonsterDef = ContentDB.get_monster(&"lich")
	add_child(mob)
	mob.call("setup", def, 1)
	mob.set_physics_process(false)
	if mob is Node3D:
		(mob as Node3D).position = Vector3(0.08, 0.05, -13.6)
		(mob as Node3D).rotation_degrees = Vector3(0, 180, 0)
	var backlight := OmniLight3D.new()
	backlight.position = Vector3(0, 2.1, -15.4)
	backlight.light_color = Color(0.58, 0.38, 0.88)
	backlight.light_energy = 6.5
	backlight.omni_range = 7.0
	backlight.omni_attenuation = 1.2
	backlight.shadow_enabled = false
	add_child(backlight)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.5, 1.55, -12.0)
	rim.light_color = Color(1.0, 0.68, 0.38)
	rim.light_energy = 2.4
	rim.omni_range = 5.0
	rim.omni_attenuation = 1.3
	add_child(rim)


func _paint_kit(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_paint_kit(child, material)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.position = _cam_origin
	add_child(_camera)
	_camera.look_at_from_position(_cam_origin, Vector3(0, 1.35, -12))


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings and _settings.visible:
			_settings.visible = false
			get_viewport().set_input_as_handled()
		elif _bestiary and _bestiary.visible:
			_bestiary.visible = false
			get_viewport().set_input_as_handled()
