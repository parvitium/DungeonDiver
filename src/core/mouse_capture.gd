class_name MouseCapture
extends RefCounted
## Dungeon mouse-capture policy. Hub stays visible; play captures; UI releases.
## Headless DisplayServer never reports MOUSE_MODE_CAPTURED, so we keep a
## parallel desired-state flag. Windowed/Windows still trusts Input.mouse_mode.

enum Context { HUB, DUNGEON_PLAY, DUNGEON_UI }

const PITCH_MIN_DEG := -85.0
const PITCH_MAX_DEG := 85.0

static var context: Context = Context.HUB
static var _desired_captured: bool = false


static func context_for(in_dungeon: bool, ui_open: bool) -> Context:
	if not in_dungeon:
		return Context.HUB
	if ui_open:
		return Context.DUNGEON_UI
	return Context.DUNGEON_PLAY


static func mode_for(p_context: Context) -> int:
	if p_context == Context.DUNGEON_PLAY:
		return Input.MOUSE_MODE_CAPTURED
	return Input.MOUSE_MODE_VISIBLE


static func apply(p_context: Context) -> int:
	context = p_context
	var mode := mode_for(p_context)
	_desired_captured = mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = mode
	return mode


static func is_captured() -> bool:
	if _is_headless():
		return _desired_captured
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


static func allows_look() -> bool:
	return context == Context.DUNGEON_PLAY and is_captured()


static func should_recapture_click(p_context: Context, captured: bool) -> bool:
	return p_context == Context.DUNGEON_PLAY and not captured


static func simulate_os_release() -> void:
	_desired_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func clamp_pitch(radians: float) -> float:
	return clampf(radians, deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
