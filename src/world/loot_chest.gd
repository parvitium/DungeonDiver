class_name LootChest
extends Interactable
## PBR chest with a hinged lid. Stays in the world after opening.

signal opened(chest: LootChest)

var chest_key: String = ""
var _lid: Node3D
var _interior_light: OmniLight3D
var _glow: MeshInstance3D
var _built: bool = false


func _ready() -> void:
	super._ready()
	_build()
	var session := _session()
	var run: Variant = session.get("run") if session else null
	if run and run.has_method("is_chest_open") and run.is_chest_open(chest_key):
		apply_open(true)


static func key_for(pos: Vector3) -> String:
	return "%d_%d_%d" % [int(round(pos.x * 10.0)), int(round(pos.y * 10.0)), int(round(pos.z * 10.0))]


func _build() -> void:
	if _built:
		return
	_built = true
	prompt = "Open chest"
	consume_on_use = true
	var wood := DungeonMaterials.wood_mat()
	var metal := DungeonMaterials.metal_mat()

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.92, 0.42, 0.58)
	body.mesh = body_mesh
	body.material_override = wood
	body.position = Vector3(0, 0.21, 0)
	add_child(body)

	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.96, 0.05, 0.62)
	band.mesh = band_mesh
	band.material_override = metal
	band.position = Vector3(0, 0.18, 0)
	add_child(band)

	var interior := MeshInstance3D.new()
	var well := BoxMesh.new()
	well.size = Vector3(0.78, 0.22, 0.44)
	interior.mesh = well
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.04, 0.03)
	dark.roughness = 1.0
	interior.material_override = dark
	interior.position = Vector3(0, 0.28, 0)
	add_child(interior)

	_lid = Node3D.new()
	_lid.name = "LidPivot"
	_lid.position = Vector3(0, 0.42, -0.29)
	add_child(_lid)
	var lid_mesh_i := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.94, 0.1, 0.6)
	lid_mesh_i.mesh = lid_mesh
	lid_mesh_i.material_override = wood
	lid_mesh_i.position = Vector3(0, 0.05, 0.3)
	_lid.add_child(lid_mesh_i)
	var lid_band := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.98, 0.04, 0.64)
	lid_band.mesh = lb
	lid_band.material_override = metal
	lid_band.position = Vector3(0, 0.1, 0.3)
	_lid.add_child(lid_band)

	_glow = MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.7, 0.02, 0.38)
	_glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.95, 0.75, 0.25, 0.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.72, 0.2)
	glow_mat.emission_energy_multiplier = 0.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.material_override = glow_mat
	_glow.position = Vector3(0, 0.32, 0)
	add_child(_glow)

	_interior_light = OmniLight3D.new()
	_interior_light.light_color = Color(1.0, 0.72, 0.28)
	_interior_light.light_energy = 0.0
	_interior_light.omni_range = 1.6
	_interior_light.position = Vector3(0, 0.34, 0)
	add_child(_interior_light)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 0.85, 0.75)
	col.shape = box
	col.position = Vector3(0, 0.4, 0)
	add_child(col)


func try_use(by: Node) -> bool:
	if used or locked:
		return false
	var ok := super.try_use(by)
	if ok:
		apply_open(false)
		var session := _session()
		var run: Variant = session.get("run") if session else null
		if run and run.has_method("mark_chest_open"):
			run.mark_chest_open(chest_key)
		opened.emit(self)
	return ok


func apply_open(instant: bool) -> void:
	used = true
	prompt = ""
	collision_layer = 0
	if _lid == null:
		_build()
	if instant:
		_lid.rotation_degrees.x = -112.0
		_finish_open_look()
		return
	var tween := create_tween()
	tween.tween_property(_lid, "rotation_degrees:x", -112.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_open_look)


func _session() -> Node:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameSession")


func _finish_open_look() -> void:
	if _interior_light:
		_interior_light.light_energy = 0.85
	if _glow and _glow.material_override is StandardMaterial3D:
		var mat := _glow.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.45
		mat.emission_energy_multiplier = 1.4
