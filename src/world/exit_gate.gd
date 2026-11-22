class_name ExitGate
extends Interactable
## Arched stone gate with a locked portcullis and an unlocked portal swirl.

var _portal: MeshInstance3D
var _portal_light: OmniLight3D
var _particles: GPUParticles3D
var _bars: Node3D
var _chain: Node3D
var _lock_sfx: AudioStreamPlayer3D
var _built: bool = false


func _ready() -> void:
	super._ready()
	prompt = "Leave through the gate"
	_build()
	refresh_lock()


func set_locked_state(is_locked: bool) -> void:
	locked = is_locked
	refresh_lock()
	if not is_locked and _lock_sfx:
		_lock_sfx.play()


func refresh_lock() -> void:
	if not _built:
		_build()
	if _bars:
		_bars.visible = locked
	if _chain:
		_chain.visible = locked
	if _portal:
		_portal.visible = not locked
	if _portal_light:
		_portal_light.visible = not locked
		_portal_light.light_energy = 0.0 if locked else 3.6
	if _particles:
		_particles.emitting = not locked
	prompt = "Sealed — defeat the boss" if locked else "Leave through the gate"


func _build() -> void:
	if _built:
		return
	_built = true
	var dungeon: DungeonTypeDef = ContentDB.get_dungeon(GameSession.run.dungeon_id) if GameSession.run else Catalog.all_dungeons()[0]
	var stone := DungeonMaterials.wall_mat(dungeon)
	var metal := DungeonMaterials.metal_mat()

	var dais := MeshInstance3D.new()
	var dais_mesh := BoxMesh.new()
	dais_mesh.size = Vector3(3.2, 0.28, 1.6)
	dais.mesh = dais_mesh
	dais.material_override = stone
	dais.position = Vector3(0, 0.14, -0.25)
	add_child(dais)

	var left := _pillar(stone)
	left.position = Vector3(-1.15, 1.45, 0)
	add_child(left)
	var right := _pillar(stone)
	right.position = Vector3(1.15, 1.45, 0)
	add_child(right)

	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(2.6, 0.38, 0.7)
	lintel.mesh = lintel_mesh
	lintel.material_override = stone
	lintel.position = Vector3(0, 2.55, 0)
	add_child(lintel)

	var arch := MeshInstance3D.new()
	var arch_mesh := CylinderMesh.new()
	arch_mesh.top_radius = 1.25
	arch_mesh.bottom_radius = 1.25
	arch_mesh.height = 0.55
	arch_mesh.rings = 8
	arch.mesh = arch_mesh
	arch.material_override = stone
	arch.rotation_degrees = Vector3(0, 0, 90)
	arch.position = Vector3(0, 2.35, 0)
	add_child(arch)

	_portal = MeshInstance3D.new()
	_portal.name = "PortalSurface"
	var portal_mesh := QuadMesh.new()
	portal_mesh.size = Vector2(1.7, 2.35)
	_portal.mesh = portal_mesh
	_portal.material_override = _swirl_mat()
	_portal.position = Vector3(0, 1.35, -0.06)
	add_child(_portal)

	_portal_light = OmniLight3D.new()
	_portal_light.light_color = Color(0.4, 0.95, 0.78)
	_portal_light.omni_range = 6.5
	_portal_light.position = Vector3(0, 1.4, -0.45)
	add_child(_portal_light)

	_particles = GPUParticles3D.new()
	_particles.position = Vector3(0, 1.35, -0.2)
	_particles.amount = 40
	_particles.lifetime = 1.6
	_particles.emitting = false
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(0.7, 1.0, 0.05)
	proc.gravity = Vector3(0, 0.4, 0)
	proc.initial_velocity_min = 0.05
	proc.initial_velocity_max = 0.25
	proc.scale_min = 0.04
	proc.scale_max = 0.1
	proc.color = Color(0.45, 1.0, 0.82, 0.7)
	_particles.process_material = proc
	var puff := SphereMesh.new()
	puff.radius = 0.05
	puff.height = 0.1
	_particles.draw_pass_1 = puff
	add_child(_particles)

	_bars = Node3D.new()
	_bars.name = "Portcullis"
	add_child(_bars)
	for i in 7:
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 2.3
		bar.mesh = cyl
		bar.material_override = metal
		bar.position = Vector3(-0.75 + float(i) * 0.25, 1.25, -0.1)
		_bars.add_child(bar)
	var cross := MeshInstance3D.new()
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(1.7, 0.06, 0.08)
	cross.mesh = cross_mesh
	cross.material_override = metal
	cross.position = Vector3(0, 1.55, -0.1)
	_bars.add_child(cross)

	_chain = Node3D.new()
	add_child(_chain)
	_add_chain(_chain, Vector3(-0.55, 1.7, -0.22))
	_add_chain(_chain, Vector3(0.55, 1.7, -0.22))

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.8, 0.9)
	col.shape = box
	col.position = Vector3(0, 1.4, 0.1)
	add_child(col)

	_lock_sfx = AudioStreamPlayer3D.new()
	_lock_sfx.stream = Sfx.attack_windup()
	_lock_sfx.volume_db = -4.0
	_lock_sfx.position = Vector3(0, 1.4, 0)
	add_child(_lock_sfx)


func _pillar(mat: Material) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 2.7, 0.7)
	p.mesh = mesh
	p.material_override = mat
	return p


func _add_chain(host: Node3D, at: Vector3) -> void:
	var metal := DungeonMaterials.metal_mat()
	for i in 4:
		var link := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.03
		torus.outer_radius = 0.07
		link.mesh = torus
		link.material_override = metal
		link.position = at + Vector3(0, -0.16 * float(i), 0)
		link.rotation_degrees = Vector3(90 if i % 2 == 0 else 0, 0, 45)
		host.add_child(link)


func _swirl_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform vec4 albedo : source_color = vec4(0.32, 0.95, 0.78, 0.88);
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float swirl = 0.5 + 0.5 * sin(a * 7.0 + TIME * 1.6 + r * 14.0);
	float veil = smoothstep(0.52, 0.12, r);
	float core = smoothstep(0.48, 0.0, r);
	float glow = veil * (0.35 + 0.65 * swirl);
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * (0.8 + glow * 2.4 + core);
	ALPHA = clamp(glow * 0.9 + core * 0.25, 0.15, 0.95);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat
