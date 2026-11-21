class_name TorchLight
extends OmniLight3D
## Cheap sine flicker so a room of torches does not look static.

var base_energy: float = 2.2
var _phase: float = 0.0


func _ready() -> void:
	base_energy = light_energy
	_phase = float(get_instance_id() % 97) * 0.17
	if light_color.is_equal_approx(Color.WHITE):
		light_color = Color(1.0, 0.62, 0.28)
	omni_range = maxf(omni_range, 7.5)
	omni_attenuation = 1.35
	shadow_enabled = false


func _process(delta: float) -> void:
	_phase += delta
	var wobble := 0.1 * sin(_phase * 7.1) + 0.05 * sin(_phase * 13.7 + 1.4)
	light_energy = base_energy * (0.9 + wobble)
	var sibling := get_parent().get_node_or_null("TorchSpot") as SpotLight3D
	if sibling:
		sibling.light_energy = sibling.get_meta("base_energy", sibling.light_energy) * (0.9 + wobble)
