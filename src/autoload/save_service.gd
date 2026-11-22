extends Node

var last_quarantine_path: String = ""
var active_slot: int = 1


func _ready() -> void:
	migrate_legacy()


func slot_path(slot: int) -> String:
	return "user://dungeondiver_slot_%d.json" % clampi(slot, 1, DD.SAVE_SLOT_COUNT)


func migrate_legacy() -> void:
	if FileAccess.file_exists(DD.LEGACY_SAVE_PATH) and not FileAccess.file_exists(slot_path(1)):
		var src := ProjectSettings.globalize_path(DD.LEGACY_SAVE_PATH)
		var dest := ProjectSettings.globalize_path(slot_path(1))
		DirAccess.copy_absolute(src, dest)


func save_game(path: String = DD.SAVE_PATH) -> bool:
	var payload := SaveCodec.payload_from_profile(GameSession.profile)
	payload["saved_unix"] = int(Time.get_unix_time_from_system())
	payload["slot"] = active_slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Save failed: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func save_active() -> bool:
	return save_game(slot_path(active_slot))


func save_slot(slot: int) -> bool:
	active_slot = clampi(slot, 1, DD.SAVE_SLOT_COUNT)
	return save_game(slot_path(active_slot))


func load_game(path: String = DD.SAVE_PATH) -> bool:
	last_quarantine_path = ""
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
	return false


func load_slot(slot: int) -> bool:
	active_slot = clampi(slot, 1, DD.SAVE_SLOT_COUNT)
	return load_game(slot_path(active_slot))


func new_game_in_slot(slot: int, char_name: String) -> void:
	active_slot = clampi(slot, 1, DD.SAVE_SLOT_COUNT)
	GameSession.reset_profile()
	var trimmed := char_name.strip_edges()
	GameSession.profile.display_name = trimmed if not trimmed.is_empty() else "Diver"
	save_slot(active_slot)


func load_failure_message() -> String:
	if last_quarantine_path.is_empty():
		return "Save couldn't be loaded."
	return "Save couldn't be loaded; backed up to %s" % last_quarantine_path


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


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func peek_slot(slot: int) -> Dictionary:
	var info := {
		"slot": clampi(slot, 1, DD.SAVE_SLOT_COUNT),
		"occupied": false,
		"corrupt": false,
		"name": "",
		"best_depth": 0,
		"gold": 0,
		"saved_unix": 0,
		"date": "Empty",
	}
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return info
	info["occupied"] = true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		info["corrupt"] = true
		info["date"] = "Unreadable"
		return info
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var profile := SaveCodec.decode_payload(parsed)
	if profile == null:
		info["corrupt"] = true
		info["date"] = "Corrupt"
		return info
	info["name"] = profile.display_name
	info["best_depth"] = profile.progression.best_depth()
	info["gold"] = profile.gold
	if parsed is Dictionary:
		info["saved_unix"] = int((parsed as Dictionary).get("saved_unix", 0))
	if int(info["saved_unix"]) > 0:
		info["date"] = Time.get_datetime_string_from_unix_time(int(info["saved_unix"]), true)
	else:
		info["date"] = "Saved"
	return info


func slot_summaries() -> Array:
	var out: Array = []
	for i in range(1, DD.SAVE_SLOT_COUNT + 1):
		out.append(peek_slot(i))
	return out


func summary_line(info: Dictionary) -> String:
	if not bool(info.get("occupied", false)):
		return "Slot %d  ·  Empty" % int(info.get("slot", 1))
	if bool(info.get("corrupt", false)):
		return "Slot %d  ·  %s" % [int(info.get("slot", 1)), str(info.get("date", "Corrupt"))]
	return "Slot %d  ·  %s  ·  best depth %d  ·  %d gold  ·  %s" % [
		int(info.get("slot", 1)),
		str(info.get("name", "Diver")),
		int(info.get("best_depth", 0)),
		int(info.get("gold", 0)),
		str(info.get("date", "")),
	]


func clear_save(path: String = DD.SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func clear_slot(slot: int) -> void:
	clear_save(slot_path(slot))


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
	push_warning("Corrupt save quarantined to %s." % dest)
