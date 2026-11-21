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
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mesh_instance)
	return root


static func make_box_with_material(size: Vector3, mat: Material, collision: bool = true) -> Node3D:
	var root := make_box(size, Color.WHITE, collision)
	apply_visual_material(root, mat)
	return root


static func apply_visual_material(root: Node, mat: Material) -> void:
	var vis := root.get_node_or_null("BodyVisual")
	if vis == null:
		vis = root.find_child("BodyVisual", true, false)
	if vis is MeshInstance3D:
		(vis as MeshInstance3D).material_override = mat
		(vis as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


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


## AABB of a node in its parent's space.
## Skinned Quaternius GLBs keep a Blender armature scale of 100 while mesh
## vertices may be in a different bind space; unskinned mesh AABBs then inflate
## by 100x and `fit_height` shrinks the posed character to a speck. Prefer the
## skeleton bone AABB when a Skeleton3D is present.
static func visual_aabb(root: Node) -> AABB:
	var mesh_acc: Array = [false, AABB()]
	var bone_acc: Array = [false, AABB()]
	_accum_aabb(root, Transform3D.IDENTITY, mesh_acc, bone_acc)
	if bone_acc[0] and (bone_acc[1] as AABB).size.y > 0.05:
		return bone_acc[1]
	return mesh_acc[1] if mesh_acc[0] else AABB()


static func fit_height(root: Node3D, height: float, snap_ground: bool = true) -> void:
	var aabb := visual_aabb(root)
	if aabb.size.y < 0.0001:
		return
	root.scale *= height / aabb.size.y
	if snap_ground:
		aabb = visual_aabb(root)
		root.position.y -= aabb.position.y


static func fit_max_extent(root: Node3D, max_dim: float) -> void:
	var aabb := visual_aabb(root)
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest < 0.0001:
		return
	root.scale *= max_dim / longest


static func _accum_aabb(n: Node, xf: Transform3D, mesh_acc: Array, bone_acc: Array) -> void:
	var next := xf
	if n is Node3D:
		next = xf * (n as Node3D).transform
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		for b in sk.get_bone_count():
			_expand(bone_acc, next * sk.get_bone_global_pose(b).origin)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var local: AABB = (n as MeshInstance3D).get_aabb()
		for i in 8:
			var corner := local.position + Vector3(
				local.size.x if (i & 1) else 0.0,
				local.size.y if (i & 2) else 0.0,
				local.size.z if (i & 4) else 0.0
			)
			_expand(mesh_acc, next * corner)
	for child in n.get_children():
		_accum_aabb(child, next, mesh_acc, bone_acc)


static func _expand(acc: Array, world: Vector3) -> void:
	if not acc[0]:
		acc[0] = true
		acc[1] = AABB(world, Vector3.ZERO)
	else:
		acc[1] = (acc[1] as AABB).expand(world)
