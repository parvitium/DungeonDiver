extends Node


func save_game(path: String = DD.SAVE_PATH) -> bool:
	var payload := SaveCodec.payload_from_profile(GameSession.profile)
	payload["saved_unix"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Save failed: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game(path: String = DD.SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return apply_payload(parsed)
	return false


func apply_payload(payload: Dictionary) -> bool:
	if int(payload.get("version", 0)) > DD.SAVE_VERSION:
		push_warning("Save version newer than game; loading what we can.")
	var profile_data: Variant = payload.get("profile", {})
	if profile_data is Dictionary:
		GameSession.profile = PlayerProfile.from_dict(profile_data)
		GameSession.profile_changed.emit()
		return true
	return false


func has_save(path: String = DD.SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func clear_save(path: String = DD.SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
