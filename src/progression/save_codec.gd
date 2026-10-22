class_name SaveCodec
extends RefCounted
## Save payload helpers with no autoload dependency (safe for headless tests).
## Every nested field is type-checked. Invalid data returns null — never SCRIPT ERROR.


static func payload_from_profile(profile: PlayerProfile) -> Dictionary:
	return {
		"version": DD.SAVE_VERSION,
		"profile": profile.to_dict(),
	}


static func decode_payload(payload: Variant) -> PlayerProfile:
	if not payload is Dictionary:
		return null
	var data: Dictionary = payload
	if data.has("version"):
		if not DD.is_number(data["version"]):
			return null
		if int(data["version"]) > DD.SAVE_VERSION:
			return null
	if data.has("profile") and not data["profile"] is Dictionary:
		return null
	var profile_data: Variant = data.get("profile", {})
	return PlayerProfile.from_dict(profile_data)


static func profile_from_payload(payload: Variant) -> PlayerProfile:
	return decode_payload(payload)


static func drop_unknown_ids(
		profile: PlayerProfile,
		item_defs: Dictionary,
		monster_defs: Dictionary,
		dungeon_defs: Dictionary
	) -> void:
	if profile == null:
		return
	profile.inventory.drop_unknown_items(item_defs)
	profile.progression.drop_unknown_ids(monster_defs, dungeon_defs)
