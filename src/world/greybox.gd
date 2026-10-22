class_name Greybox
extends RefCounted
## Primitive builders. Swap MeshInstance3D children named *Visual for .glb later.


static func make_box(size: Vector3, color: Color, collision: bool = true) -> Node3D:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
		root.collision_layer = DD.WORLD_LAYER
		root.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		root.add_child(shape)
	else:
		root = Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BodyVisual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color)
	root.add_child(mesh_instance)
	return root


static func make_material(color: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mat.metallic = 0.05
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


static func make_capsule_visual(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BodyVisual"
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color)
	return mesh_instance
