class_name CombatVfx
extends Node
## Pooled GPUParticles3D / Decal combat effects. Bind once per dungeon world.

const POOL_CAP := 12
const BONE_PILE_LIFE := 9.0

var _free: Dictionary = {}
var _blob: Texture2D


func _ready() -> void:
	add_to_group("combat_vfx")
	_blob = _make_blob()


static func from_node(from: Node) -> CombatVfx:
	if from == null or not from.is_inside_tree():
		return null
	var found := from.get_tree().get_first_node_in_group("combat_vfx")
	if found is CombatVfx:
		return found as CombatVfx
	var vfx := CombatVfx.new()
	from.get_tree().root.add_child(vfx)
	return vfx


static func material_for(monster_id: StringName) -> StringName:
	match String(monster_id):
		"skeleton":
			return &"bone"
		"wraith", "lich":
			return &"magic"
		"cave_troll":
			return &"stone"
		_:
			return &"flesh"


static func projectile_kind_for(monster_id: StringName) -> StringName:
	match String(monster_id):
		"lich":
			return &"ice"
		"wraith":
			return &"bolt"
		_:
			return &"bolt"


func cast_flash(at: Vector3, kind: StringName) -> void:
	var color := _kind_color(kind)
	_burst("cast", at, color, 16, 0.35, 2.2, Vector3(0, 1, 0), 0.6)
	_pulse_light(at, color, 4.5, 2.8, 0.28)


func hit(at: Vector3, toward: Vector3, mat: StringName) -> void:
	match String(mat):
		"bone":
			_burst("bone", at, Color(0.86, 0.82, 0.72), 22, 0.45, 3.4, toward, 1.4)
		"flesh":
			_burst("blood", at, Color(0.55, 0.05, 0.06), 20, 0.4, 2.8, toward, 1.6)
			_blood_decal(at)
		"stone":
			_burst("dust", at, Color(0.55, 0.5, 0.42), 18, 0.5, 1.6, toward, 1.1)
		"metal":
			_burst("spark", at, Color(1.0, 0.82, 0.35), 18, 0.28, 5.5, toward, 2.4)
		"magic":
			_burst("magic", at, Color(0.45, 0.8, 1.0), 18, 0.4, 3.2, toward, 1.5)
		_:
			_burst("spark", at, Color(0.95, 0.75, 0.4), 12, 0.3, 3.0, toward, 1.8)
	_pulse_light(at, Color(1.0, 0.85, 0.6), 2.2, 1.6, 0.12)


func sword_impact(at: Vector3, toward: Vector3) -> void:
	_burst("spark", at, Color(1.0, 0.88, 0.45), 14, 0.22, 6.0, toward, 2.8)
	_pulse_light(at, Color(1.0, 0.9, 0.55), 2.4, 1.4, 0.1)


func death(at: Vector3, mat: StringName, host: Node3D) -> void:
	match String(mat):
		"bone":
			_bone_pile(at, host)
		"magic":
			_burst("magic_death", at, Color(0.5, 0.75, 1.0), 36, 0.7, 4.5, Vector3.UP, 2.4)
			_pulse_light(at, Color(0.45, 0.85, 1.0), 7.0, 4.0, 0.45)
		_:
			_burst("death", at, Color(0.45, 0.12, 0.1), 28, 0.55, 2.4, Vector3.UP, 1.8)
			if mat == &"flesh":
				_blood_decal(at)


func flash_enemy(root: Node) -> void:
	if root == null:
		return
	_flash_walk(root, 0)


static func dress_projectile(host: Node3D, kind: StringName, color: Color) -> void:
	match String(kind):
		"fireball":
			_orb(host, Color(1.0, 0.45, 0.12), 0.2, 5.5, 4.5)
			_attach_trail(host, Color(1.0, 0.4, 0.08), 36, 0.45)
		"ice":
			_shard(host, Color(0.65, 0.85, 1.0))
			_attach_trail(host, Color(0.7, 0.9, 1.0), 28, 0.55)
		"arrow":
			_arrow(host, Color(0.72, 0.62, 0.4))
			_attach_trail(host, Color(0.85, 0.85, 0.8), 18, 0.25)
		_:
			_orb(host, color.lerp(Color(0.7, 0.9, 1.0), 0.4), 0.16, 4.2, 4.0)
			_attach_trail(host, color, 28, 0.35)


static func make_swing_trail() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "SwingTrail"
	p.amount = 24
	p.lifetime = 0.18
	p.local_coords = true
	p.emitting = false
	p.process_material = _particle_proc(Color(0.85, 0.88, 0.95, 0.55), 0.4, 0.15, Vector3(0, 0, 1), 0.2)
	p.draw_pass_1 = _sphere_mesh(0.035)
	return p


static func _orb(host: Node3D, color: Color, radius: float, emit_e: float, light_e: float) -> void:
	var core := MeshInstance3D.new()
	core.name = "BoltVisual"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	core.mesh = sphere
	core.material_override = _emit_mat(color, emit_e, 0.9)
	host.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = light_e
	light.omni_range = 4.4
	host.add_child(light)


static func _shard(host: Node3D, color: Color) -> void:
	var core := MeshInstance3D.new()
	core.name = "BoltVisual"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.46)
	core.mesh = mesh
	core.material_override = _emit_mat(color, 3.4, 0.85)
	host.add_child(core)
	var mist := GPUParticles3D.new()
	mist.amount = 16
	mist.lifetime = 0.4
	mist.local_coords = false
	mist.process_material = _particle_proc(Color(0.8, 0.92, 1.0, 0.5), 0.2, 0.05, Vector3(0, 0.4, 1), 0.3)
	mist.draw_pass_1 = _sphere_mesh(0.05)
	host.add_child(mist)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.2
	light.omni_range = 3.8
	host.add_child(light)


static func _arrow(host: Node3D, color: Color) -> void:
	var shaft := MeshInstance3D.new()
	shaft.name = "BoltVisual"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 0.55
	shaft.mesh = cyl
	shaft.material_override = Greybox.make_material(color)
	shaft.rotation_degrees = Vector3(90, 0, 0)
	host.add_child(shaft)
	var head := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.08, 0.08, 0.12)
	head.mesh = prism
	head.material_override = Greybox.make_material(Color(0.55, 0.55, 0.58))
	head.position = Vector3(0, 0, -0.32)
	host.add_child(head)


static func _attach_trail(host: Node3D, color: Color, amount: int, life: float) -> void:
	var trail := GPUParticles3D.new()
	trail.amount = amount
	trail.lifetime = life
	trail.local_coords = false
	trail.process_material = _particle_proc(color, 0.15, 0.04, Vector3(0, 0, 1), 0.35)
	trail.draw_pass_1 = _sphere_mesh(0.05)
	host.add_child(trail)


func _burst(kind: String, at: Vector3, color: Color, amount: int, life: float, speed: float, dir: Vector3, spread: float) -> void:
	var p := _acquire(kind, func() -> GPUParticles3D:
		var n := GPUParticles3D.new()
		n.one_shot = true
		n.explosiveness = 0.92
		n.draw_pass_1 = _sphere_mesh(0.045)
		return n
	) as GPUParticles3D
	p.amount = amount
	p.lifetime = life
	p.global_position = at
	p.process_material = _particle_proc(color, speed, 0.15, dir, spread)
	p.restart()
	p.emitting = true
	p.visible = true
	_release_later(kind, p, life + 0.05)


func _blood_decal(at: Vector3) -> void:
	var d := _acquire("decal", func() -> Decal:
		var n := Decal.new()
		n.size = Vector3(0.7, 0.5, 0.7)
		n.modulate = Color(0.42, 0.04, 0.04, 0.85)
		n.texture_albedo = _blob
		n.cull_mask = 0xFFFFF
		return n
	) as Decal
	d.global_position = at + Vector3(0, 0.02, 0)
	d.visible = true
	d.modulate.a = 0.85
	var tween := create_tween()
	tween.tween_property(d, "modulate:a", 0.0, 4.5).set_delay(1.2)
	tween.tween_callback(_release.bind("decal", d))


func _bone_pile(at: Vector3, host: Node3D) -> void:
	var pile := Node3D.new()
	pile.name = "BonePile"
	var parent: Node = host.get_parent() if host else self
	parent.add_child(pile)
	pile.global_position = at
	var bone_mat := Greybox.make_material(Color(0.86, 0.82, 0.72))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 100.0 + at.z * 10.0)
	for i in 9:
		var chip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(0.07, 0.2), rng.randf_range(0.03, 0.06), rng.randf_range(0.04, 0.1))
		chip.mesh = box
		chip.material_override = bone_mat
		chip.position = Vector3(rng.randf_range(-0.25, 0.25), 0.04, rng.randf_range(-0.25, 0.25))
		chip.rotation_degrees = Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 180), rng.randf_range(-15, 15))
		pile.add_child(chip)
	_burst("bone", at, Color(0.86, 0.82, 0.72), 16, 0.4, 2.2, Vector3.UP, 1.2)
	if not is_inside_tree():
		return
	var wait := get_tree().create_timer(BONE_PILE_LIFE)
	wait.timeout.connect(func() -> void:
		if not is_instance_valid(pile):
			return
		var tween := pile.create_tween()
		tween.tween_property(pile, "position:y", pile.position.y - 0.7, 1.1)
		tween.parallel().tween_property(pile, "modulate:a", 0.0, 1.1)
		tween.tween_callback(pile.queue_free)
	)


func _pulse_light(at: Vector3, color: Color, energy: float, range_m: float, dur: float) -> void:
	var light := _acquire("light", func() -> OmniLight3D: return OmniLight3D.new()) as OmniLight3D
	light.global_position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.visible = true
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, dur)
	tween.tween_callback(_release.bind("light", light))


func _flash_walk(n: Node, depth: int) -> void:
	if depth > 8:
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var src: Material = mi.material_override if mi.material_override else mi.get_active_material(0)
		if src is StandardMaterial3D:
			var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.85, 0.7)
			mat.emission_energy_multiplier = 2.8
			mi.material_override = mat
			var tween := create_tween()
			tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)
	for c in n.get_children():
		_flash_walk(c, depth + 1)


func _acquire(kind: String, factory: Callable) -> Node:
	var list: Array = _free.get(kind, [])
	var node: Node
	if list.size() > 0:
		node = list.pop_back()
		_free[kind] = list
	else:
		node = factory.call()
		add_child(node)
	if node is Node3D:
		(node as Node3D).visible = true
	return node


func _release(kind: String, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	if node is Node3D:
		(node as Node3D).visible = false
	var list: Array = _free.get(kind, [])
	if list.size() >= POOL_CAP:
		node.queue_free()
		return
	list.append(node)
	_free[kind] = list


func _release_later(kind: String, node: Node, delay: float) -> void:
	if not is_inside_tree():
		_release(kind, node)
		return
	get_tree().create_timer(delay).timeout.connect(_release.bind(kind, node))


func pool_free_count(kind: String) -> int:
	var list: Array = _free.get(kind, [])
	return list.size()


static func _particle_proc(color: Color, speed: float, scale: float, dir: Vector3, spread: float) -> ParticleProcessMaterial:
	var proc := ParticleProcessMaterial.new()
	proc.direction = dir if dir.length() > 0.01 else Vector3.UP
	proc.spread = rad_to_deg(spread) if spread < 4.0 else spread * 20.0
	proc.initial_velocity_min = speed * 0.35
	proc.initial_velocity_max = speed
	proc.gravity = Vector3(0, -4.0, 0)
	proc.scale_min = scale * 0.5
	proc.scale_max = scale
	proc.color = color
	return proc


static func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


static func _emit_mat(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.22
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func _kind_color(kind: StringName) -> Color:
	match String(kind):
		"fireball":
			return Color(1.0, 0.45, 0.1)
		"ice":
			return Color(0.6, 0.85, 1.0)
		"arrow":
			return Color(0.9, 0.85, 0.7)
		_:
			return Color(0.5, 0.8, 1.0)


func _make_blob() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var dx := (float(x) - 32.0) / 32.0
			var dy := (float(y) - 32.0) / 32.0
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(0.45, 0.05, 0.04, a))
	return ImageTexture.create_from_image(img)
