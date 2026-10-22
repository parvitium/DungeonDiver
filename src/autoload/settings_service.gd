extends Node
## Persisted player prefs. Visual quality is applied by VisualLook.

signal changed

const PATH := "user://dungeondiver_settings.json"
const QUALITIES: PackedStringArray = ["low", "medium", "high", "ultra"]

var mouse_sensitivity: float = 1.0
var fov: float = 75.0
var master_volume: float = 0.85
var graphics_quality: String = "high"


func _ready() -> void:
	load_settings()
	apply()


func load_settings(path: String = PATH) -> bool:
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


func save_settings(path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true


func to_dict() -> Dictionary:
	return {
		"mouse_sensitivity": mouse_sensitivity,
		"fov": fov,
		"master_volume": master_volume,
		"graphics_quality": graphics_quality,
	}


func apply_dict(data: Dictionary) -> void:
	if DD.is_number(data.get("mouse_sensitivity")):
		mouse_sensitivity = clampf(float(data["mouse_sensitivity"]), 0.2, 3.0)
	if DD.is_number(data.get("fov")):
		fov = clampf(float(data["fov"]), 50.0, 110.0)
	if DD.is_number(data.get("master_volume")):
		master_volume = clampf(float(data["master_volume"]), 0.0, 1.0)
	var quality := str(data.get("graphics_quality", graphics_quality)).to_lower()
	if QUALITIES.has(quality):
		graphics_quality = quality


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.2, 3.0)
	_commit()


func set_fov(value: float) -> void:
	fov = clampf(value, 50.0, 110.0)
	_commit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_graphics_quality(value: String) -> void:
	var quality := value.to_lower()
	if QUALITIES.has(quality):
		graphics_quality = quality
	_commit()


func quality_index() -> int:
	var idx := QUALITIES.find(graphics_quality)
	return idx if idx >= 0 else 2


func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		if master_volume <= 0.0001:
			AudioServer.set_bus_volume_db(bus, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))
	if is_inside_tree():
		var vp := get_viewport()
		if vp:
			VisualLook.apply_viewport(vp, graphics_quality)
	changed.emit()


func _commit() -> void:
	apply()
	save_settings()
