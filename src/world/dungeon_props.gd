class_name DungeonProps
extends RefCounted
## Corner dressing: PBR crates/barrels/pillars plus a few CC0 GLB props.
## Collision stays off the door lanes, spawns, chest, exit, and start plinth.


const TORCH_GLB := "res://assets/models/props/Torch_wall.glb"
const CRATE_GLB := "res://assets/models/props/Crate.glb"
const BARREL_GLB := "res://assets/models/props/Barrel.glb"
const CHEST_GLB := "res://assets/models/props/Chest.glb"
const BONES_GLB := "res://assets/models/props/Bones.glb"
const ROCKS := [
	"res://assets/models/props/Rock1.glb",
	"res://assets/models/props/Rock2.glb",
	"res://assets/models/props/Rock3.glb",
]

const CORNERS := [
	Vector3(5.35, 0.0, 5.35),
	Vector3(-5.35, 0.0, 5.35),
	Vector3(5.35, 0.0, -5.35),
	Vector3(-5.35, 0.0, -5.35),
]


static func instance_glb(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if packed is PackedScene:
		var node := (packed as PackedScene).instantiate() as Node3D
		_strip_collision(node)
		return node
	return null


static func place_torch(parent: Node3D, world_pos: Vector3, inward: Vector3, warm: Color, cast_shadow: bool) -> void:
	var holder := Node3D.new()
	holder.name = "Torch"
	holder.position = world_pos
	var face := Vector3(inward.x, 0, inward.z)
	if face.length() > 0.05:
		holder.basis = Basis.looking_at(face.normalized(), Vector3.UP)
	parent.add_child(holder)
	_build_sconce(holder, warm, cast_shadow)


static func _build_sconce(holder: Node3D, warm: Color, cast_shadow: bool) -> void:
	# Holder -Z faces into the room. Built from PBR primitives so scale/rotation
	# does not depend on Blender-exported GLB unit conversion.
	var metal := DungeonMaterials.metal_mat()
	var wood := DungeonMaterials.wood_mat()

	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.16, 0.28, 0.045)
	plate.mesh = plate_mesh
	plate.material_override = metal
	plate.position = Vector3(0, 0, 0.02)
	holder.add_child(plate)

	var arm := MeshInstance3D.new()
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.018
	arm_mesh.bottom_radius = 0.022
	arm_mesh.height = 0.22
	arm.mesh = arm_mesh
	arm.material_override = metal
	arm.rotation_degrees = Vector3(-90, 0, 0)
	arm.position = Vector3(0, -0.02, -0.1)
	holder.add_child(arm)

	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.028
	stick_mesh.bottom_radius = 0.038
	stick_mesh.height = 0.42
	stick.mesh = stick_mesh
	stick.material_override = wood
	stick.rotation_degrees = Vector3(-28, 0, 0)
	stick.position = Vector3(0, 0.14, -0.22)
	holder.add_child(stick)

	var bowl := MeshInstance3D.new()
	var bowl_mesh := SphereMesh.new()
	bowl_mesh.radius = 0.055
	bowl_mesh.height = 0.07
	bowl.mesh = bowl_mesh
	bowl.material_override = metal
	bowl.position = Vector3(0, 0.32, -0.32)
	holder.add_child(bowl)

	var flame := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.06
	ball.height = 0.14
	flame.mesh = ball
	flame.material_override = DungeonMaterials.flame_mat()
	flame.position = Vector3(0, 0.4, -0.34)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(flame)

	var omni := TorchLight.new()
	omni.position = Vector3(0, 0.38, -0.36)
	omni.light_color = warm
	omni.light_energy = 3.1
	omni.omni_range = 10.0
	omni.shadow_enabled = false
	holder.add_child(omni)

	if cast_shadow:
		var spot := SpotLight3D.new()
		spot.name = "TorchSpot"
		spot.position = Vector3(0, 0.36, -0.4)
		spot.rotation_degrees = Vector3(-42, 0, 0)
		spot.light_color = warm
		spot.light_energy = 4.6
		spot.spot_range = 12.0
		spot.spot_angle = 52.0
		spot.shadow_enabled = true
		spot.shadow_bias = 0.04
		spot.shadow_blur = 1.4
		spot.set_meta("base_energy", 4.6)
		holder.add_child(spot)


static func dress_room(
		nav: NavigationRegion3D,
		parent: Node3D,
		room: RoomSpec,
		def: DungeonTypeDef,
		reserved: Array
	) -> void:
	var origin := room.world_origin()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [String(def.id), str(room.cell), str(room.kind)])
	var free_corners: Array[Vector3] = []
	for offset in CORNERS:
		var world: Vector3 = origin + offset
		if _too_close(world, reserved, 2.15):
			continue
		free_corners.append(world)
	if free_corners.is_empty():
		return

	var wall := DungeonMaterials.wall_mat(def)
	var wood := DungeonMaterials.wood_mat()

	# Pillars: stone, same PBR as walls so they read as architecture.
	var pillar_count := 2 if room.kind != DD.RoomKind.BOSS else mini(4, free_corners.size())
	for i in mini(pillar_count, free_corners.size()):
		var at: Vector3 = free_corners[i]
		nav.add_child(_pillar(at, wall, room.kind == DD.RoomKind.BOSS))

	var leftover: Array[Vector3] = []
	for i in range(pillar_count, free_corners.size()):
		leftover.append(free_corners[i])
	if leftover.is_empty() and free_corners.size() > 0:
		# Shift crate off the pillar a little along the wall.
		leftover.append(free_corners[0] + Vector3(0.85, 0, -0.2))

	if leftover.size() > 0:
		var crate_at: Vector3 = leftover[0]
		if not _too_close(crate_at, reserved, 1.8):
			nav.add_child(_crate_stack(crate_at, wood, rng))

	if leftover.size() > 1:
		var barrel_at: Vector3 = leftover[1]
		if not _too_close(barrel_at, reserved, 1.8):
			nav.add_child(_barrels(barrel_at, wood, rng))

	# Visual-only rubble / bones along a wall, no collision so paths stay open.
	var rubble_at := origin + Vector3(rng.randf_range(-4.6, 4.6), 0.0, 5.55 * (1.0 if rng.randf() > 0.5 else -1.0))
	if absf(rubble_at.x - origin.x) > 1.8 and not _too_close(rubble_at, reserved, 1.6):
		parent.add_child(_rubble(rubble_at, def, rng))

	if String(def.id) == "crypt" and leftover.size() > 0:
		var bones := instance_glb(BONES_GLB)
		if bones:
			bones.rotation.y = rng.randf() * TAU
			parent.add_child(bones)
			Greybox.fit_max_extent(bones, 0.7)
			var baabb := Greybox.visual_aabb(bones)
			bones.position = leftover[0] + Vector3(0.7, -baabb.position.y, 0.55)


static func make_chest_visual() -> Node3D:
	var mesh := instance_glb(CHEST_GLB)
	if mesh:
		Greybox.fit_height(mesh, 0.7)
		return mesh
	return Greybox.make_box_with_material(Vector3(0.9, 0.7, 0.6), DungeonMaterials.wood_mat(), false)


static func _pillar(at: Vector3, mat: Material, tall: bool) -> Node3D:
	var h := 3.55 if tall else 3.15
	var root := Node3D.new()
	root.position = at
	root.set_meta("asset_socket", "prop_pillar")
	var base := Greybox.make_box_with_material(Vector3(0.85, 0.22, 0.85), mat, true)
	base.position = Vector3(0, 0.11, 0)
	root.add_child(base)
	var shaft := Greybox.make_box_with_material(Vector3(0.58, h, 0.58), mat, true)
	shaft.position = Vector3(0, 0.22 + h * 0.5, 0)
	root.add_child(shaft)
	var cap := Greybox.make_box_with_material(Vector3(0.78, 0.16, 0.78), mat, true)
	cap.position = Vector3(0, 0.22 + h + 0.08, 0)
	root.add_child(cap)
	return root


static func _crate_stack(at: Vector3, wood: Material, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.set_meta("asset_socket", "prop_crate")
	var glb := instance_glb(CRATE_GLB)
	if glb:
		glb.rotation.y = rng.randf_range(-0.4, 0.4)
		root.add_child(glb)
		Greybox.fit_height(glb, 0.72)
		var shape_body := StaticBody3D.new()
		shape_body.collision_layer = DD.WORLD_LAYER
		shape_body.collision_mask = 0
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.85, 0.85, 0.85)
		col.shape = box
		col.position = Vector3(0, 0.42, 0)
		shape_body.add_child(col)
		root.add_child(shape_body)
		# Second crate slightly offset, visual only if the GLB is large.
		var glb2 := instance_glb(CRATE_GLB)
		if glb2:
			glb2.rotation.y = 0.7
			root.add_child(glb2)
			Greybox.fit_height(glb2, 0.5)
			glb2.position = Vector3(0.55, 0.0, 0.15)
		return root
	var a := Greybox.make_box_with_material(Vector3(0.72, 0.68, 0.72), wood, true)
	a.position = Vector3(0, 0.34, 0)
	root.add_child(a)
	var b := Greybox.make_box_with_material(Vector3(0.55, 0.5, 0.55), wood, true)
	b.position = Vector3(0.42, 0.25, 0.12)
	b.rotation.y = 0.35
	root.add_child(b)
	return root


static func _barrels(at: Vector3, wood: Material, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.set_meta("asset_socket", "prop_barrel")
	var glb := instance_glb(BARREL_GLB)
	if glb:
		glb.rotation.y = rng.randf() * TAU
		root.add_child(glb)
		Greybox.fit_height(glb, 0.82)
		var shape_body := StaticBody3D.new()
		shape_body.collision_layer = DD.WORLD_LAYER
		shape_body.collision_mask = 0
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.38
		cyl.height = 0.85
		col.shape = cyl
		col.position = Vector3(0, 0.42, 0)
		shape_body.add_child(col)
		root.add_child(shape_body)
		return root
	root.add_child(_barrel_primitive(Vector3.ZERO, wood))
	root.add_child(_barrel_primitive(Vector3(0.55, 0, 0.2), wood))
	return root


static func _barrel_primitive(offset: Vector3, wood: Material) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = DD.WORLD_LAYER
	body.collision_mask = 0
	body.position = offset
	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.32
	cyl_shape.height = 0.78
	col.shape = cyl_shape
	col.position = Vector3(0, 0.39, 0)
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.78
	mesh.mesh = cyl
	mesh.material_override = wood
	mesh.position = Vector3(0, 0.39, 0)
	body.add_child(mesh)
	var hoop := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.335
	ring.bottom_radius = 0.335
	ring.height = 0.05
	hoop.mesh = ring
	hoop.material_override = DungeonMaterials.metal_mat()
	hoop.position = Vector3(0, 0.22, 0)
	body.add_child(hoop)
	return body


static func _rubble(at: Vector3, def: DungeonTypeDef, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.set_meta("asset_socket", "prop_rubble")
	var mat := DungeonMaterials.wall_mat(def)
	for i in 4:
		var chunk := Greybox.make_box_with_material(
			Vector3(rng.randf_range(0.22, 0.55), rng.randf_range(0.12, 0.28), rng.randf_range(0.2, 0.48)),
			mat,
			false
		)
		chunk.position = Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.06, 0.16), rng.randf_range(-0.25, 0.25))
		chunk.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		root.add_child(chunk)
	var rock := instance_glb(ROCKS[rng.randi() % ROCKS.size()])
	if rock:
		rock.rotation.y = rng.randf() * TAU
		root.add_child(rock)
		Greybox.fit_max_extent(rock, rng.randf_range(0.35, 0.55))
		var raabb := Greybox.visual_aabb(rock)
		rock.position.y = -raabb.position.y
	return root


static func _too_close(point: Vector3, reserved: Array, radius: float) -> bool:
	for item in reserved:
		if item == null:
			continue
		var other: Vector3 = item
		other.y = point.y
		if point.distance_to(other) < radius:
			return true
	return false


static func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_strip_collision(child)
