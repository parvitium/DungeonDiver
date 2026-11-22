class_name GameSettings
extends RefCounted
## Graphics, audio, look, fullscreen, and keybinds. Disk: user://dungeondiver_settings.json

const PATH := "user://dungeondiver_settings.json"
const BINDABLE := [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "sprint", "melee", "block", "cast", "interact",
	"toggle_inventory", "toggle_bestiary", "pause_menu",
]

var mouse_sensitivity: float = 0.0022
var invert_y: bool = false
var music_volume: float = 0.7
var sfx_volume: float = 0.85
var fullscreen: bool = false
var msaa: int = 2
var fxaa: bool = true
var keybinds: Dictionary = {}


func load_from_disk() -> void:
	if not FileAccess.file_exists(PATH):
		_apply()
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_apply()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		from_dict(parsed)
	_apply()


func save_to_disk() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))


func to_dict() -> Dictionary:
	return {
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"msaa": msaa,
		"fxaa": fxaa,
		"keybinds": keybinds.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	mouse_sensitivity = clampf(float(d.get("mouse_sensitivity", mouse_sensitivity)), 0.0004, 0.012)
	invert_y = bool(d.get("invert_y", invert_y))
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	msaa = clampi(int(d.get("msaa", msaa)), 0, 3)
	fxaa = bool(d.get("fxaa", fxaa))
	var binds: Variant = d.get("keybinds", {})
	if binds is Dictionary:
		keybinds = (binds as Dictionary).duplicate()


func _apply() -> void:
	_apply_audio()
	_apply_window()
	_apply_graphics()
	_apply_keybinds()


func apply_all() -> void:
	_apply()
	save_to_disk()


func _apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(clampf(music_volume * 0.35 + sfx_volume * 0.65, 0.001, 1.0)))
	_ensure_bus("Music", music_volume)
	_ensure_bus("SFX", sfx_volume)


func _ensure_bus(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(volume, 0.001, 1.0)))
	AudioServer.set_bus_mute(idx, volume <= 0.001)


func _apply_window() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_graphics() -> void:
	var vp := Engine.get_main_loop()
	if vp is SceneTree:
		var tree := vp as SceneTree
		if tree.root:
			match msaa:
				1:
					tree.root.msaa_3d = Viewport.MSAA_2X
				2:
					tree.root.msaa_3d = Viewport.MSAA_4X
				3:
					tree.root.msaa_3d = Viewport.MSAA_8X
				_:
					tree.root.msaa_3d = Viewport.MSAA_DISABLED
			tree.root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if fxaa else Viewport.SCREEN_SPACE_AA_DISABLED


func _apply_keybinds() -> void:
	for action in BINDABLE:
		if not InputMap.has_action(action):
			continue
		if not keybinds.has(action):
			continue
		var code := int(keybinds[action])
		if code <= 0:
			continue
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = code as Key
		InputMap.action_add_event(action, ev)


static func action_label(action: String) -> String:
	match action:
		"move_forward":
			return "Move forward"
		"move_back":
			return "Move back"
		"move_left":
			return "Move left"
		"move_right":
			return "Move right"
		"jump":
			return "Jump"
		"sprint":
			return "Sprint"
		"melee":
			return "Melee"
		"block":
			return "Block"
		"cast":
			return "Cast"
		"interact":
			return "Interact"
		"toggle_inventory":
			return "Pack"
		"toggle_bestiary":
			return "Bestiary"
		"pause_menu":
			return "Pause"
		_:
			return action.replace("_", " ").capitalize()


static func current_key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
		if ev is InputEventMouseButton:
			return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return "—"
