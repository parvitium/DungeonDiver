class_name TorchLight
extends OmniLight3D
## Warm flickering torch. Particles are skipped on headless boots.


var base_energy: float = 2.8
var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	light_color = Color(1.0, 0.62, 0.28)
	light_energy = base_energy
	omni_range = 9.5
	omni_attenuation = 1.15
	VisualLook.configure_omni(self, true)
	if not VisualLook.is_headless():
		_embers()


func _process(delta: float) -> void:
	_phase += delta * (7.5 + base_energy)
	var flicker := 0.82 + 0.12 * sin(_phase) + 0.08 * sin(_phase * 2.37 + 1.1)
	light_energy = base_energy * flicker


func _embers() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "Embers"
	dust.amount = 18
	dust.lifetime = 1.3
	dust.preprocess = 0.4
	dust.visibility_aabb = AABB(Vector3(-0.6, -0.2, -0.6), Vector3(1.2, 1.8, 1.2))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 18.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.15
	mat.gravity = Vector3(0, 0.6, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.06
	mat.color = Color(1.0, 0.55, 0.15, 0.9)
	dust.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.03
	draw.height = 0.06
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(1.0, 0.45, 0.1)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.4, 0.05)
	ember_mat.emission_energy_multiplier = 4.0
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.material = ember_mat
	dust.draw_pass_1 = draw
	add_child(dust)
