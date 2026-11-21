class_name LookSettings
extends RefCounted
## Mouse look prefs. Separate from the profile save so New Game does not reset them.

const PATH := "user://dungeondiver_look.json"
const MIN_SENSITIVITY := 0.2
const MAX_SENSITIVITY := 3.0
const DEFAULT_SENSITIVITY := 1.0

var sensitivity: float = DEFAULT_SENSITIVITY
var invert_y: bool = false


func load_from_disk(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		apply_dict(parsed)
		return true
	return false


func save_to_disk(path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true


func to_dict() -> Dictionary:
	return {
		"mouse_sensitivity": sensitivity,
		"invert_y": invert_y,
	}


func apply_dict(data: Dictionary) -> void:
	if DD.is_number(data.get("mouse_sensitivity")):
		sensitivity = clampf(float(data["mouse_sensitivity"]), MIN_SENSITIVITY, MAX_SENSITIVITY)
	if data.has("invert_y"):
		invert_y = bool(data["invert_y"])


func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	save_to_disk()


func set_invert_y(value: bool) -> void:
	invert_y = value
	save_to_disk()


func scale_delta(raw: Vector2) -> Vector2:
	var y := -raw.y if invert_y else raw.y
	return Vector2(raw.x, y) * clampf(sensitivity, MIN_SENSITIVITY, MAX_SENSITIVITY)
