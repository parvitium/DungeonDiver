class_name SaveCodec
extends RefCounted
## Save payload helpers with no autoload dependency (safe for headless tests).


static func payload_from_profile(profile: PlayerProfile) -> Dictionary:
	return {
		"version": DD.SAVE_VERSION,
		"profile": profile.to_dict(),
	}


static func profile_from_payload(payload: Dictionary) -> PlayerProfile:
	return PlayerProfile.from_dict(payload.get("profile", {}))
