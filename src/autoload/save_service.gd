extends Node

var last_quarantine_path: String = ""


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
	if parsed is Dictionary and apply_payload(parsed):
		return true
	_quarantine_file(path)
	GameSession.reset_profile()
	return false


func apply_payload(payload: Variant) -> bool:
	var decoded := SaveCodec.decode_payload(payload)
	if decoded == null:
		return false
	SaveCodec.drop_unknown_ids(decoded, ContentDB.items, ContentDB.monsters, ContentDB.dungeons)
	GameSession.profile = decoded
	GameSession.profile_changed.emit()
	return true


func has_save(path: String = DD.SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func clear_save(path: String = DD.SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _quarantine_file(path: String) -> void:
	var stamp := int(Time.get_unix_time_from_system())
	var dest := "%s.corrupt-%d" % [path, stamp]
	var src_abs := ProjectSettings.globalize_path(path)
	var dest_abs := ProjectSettings.globalize_path(dest)
	if DirAccess.copy_absolute(src_abs, dest_abs) != OK:
		push_error("Failed to quarantine corrupt save: %s" % path)
		return
	DirAccess.remove_absolute(src_abs)
	last_quarantine_path = dest
	push_warning("Corrupt save quarantined to %s; started a fresh profile." % dest)
