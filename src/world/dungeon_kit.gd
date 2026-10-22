class_name DungeonKit
extends RefCounted
## Modular dungeon pieces with collision, UVs, trim, wear, and authored GLB overlays.


static func theme_of(def: DungeonTypeDef) -> StringName:
	if def != null and String(def.id) == "cavern":
		return &"cavern"
	return &"crypt"


static func collider(size: Vector3, socket: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = DD.WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if not socket.is_empty():
		body.set_meta("asset_socket", socket)
	return body


static func slab(size: Vector3, material: Material, socket: String, tile: float = 1.0) -> StaticBody3D:
	var body := collider(size, socket)
	var visual := MeshFactory.visual(MeshFactory.beveled_box(size, 0.03, tile), material, "BodyVisual")
	body.add_child(visual)
	_overlay(body, socket)
	return body


static func flagstone_floor(size: Vector3, theme: StringName, seed_value: int) -> StaticBody3D:
	var body := collider(size, "floor")
	var grout := MeshFactory.visual(MeshFactory.box(Vector3(size.x, 0.04, size.z), 1.2), PBRLibrary.wear(theme), "Grout")
	grout.position = Vector3(0, size.y * 0.5 - 0.05, 0)
	body.add_child(grout)
	var visual := MeshFactory.visual(MeshFactory.flagstones(size, 1.0, seed_value), PBRLibrary.floor_mat(theme), "Flagstone")
	visual.position = Vector3(0, size.y * 0.5 - 0.01, 0)
	body.add_child(visual)
	body.set_meta("asset_socket", "floor")
	return body


static func vaulted_ceiling(size: Vector3, theme: StringName, wall_h: float) -> Node3D:
	var rise := clampf(wall_h * 0.34, 0.95, 1.7)
	var root := Node3D.new()
	root.name = "Vault"
	root.set_meta("asset_socket", "ceiling")
	var visual := MeshFactory.visual(MeshFactory.vault_ceiling(size, rise, 1.1, 8), PBRLibrary.ceiling(theme), "VaultMesh")
	root.add_child(visual)
	for i in 3:
		var t := (float(i) / 2.0 - 0.5)
		var rib := MeshFactory.visual(
			MeshFactory.beveled_box(Vector3(size.x - 0.8, 0.12, 0.16), 0.02, 0.7),
			PBRLibrary.trim(theme),
			"VaultRib"
		)
		rib.position = Vector3(0, rise * 0.35, t * (size.z - 1.6))
		root.add_child(rib)
	return root


static func rounded_corners(parent: Node3D, origin: Vector3, theme: StringName, wall_h: float) -> void:
	var inset := DD.ROOM_SIZE * 0.5 - 0.34
	for offset in [Vector3(inset, 0, inset), Vector3(-inset, 0, inset), Vector3(inset, 0, -inset), Vector3(-inset, 0, -inset)]:
		var col := MeshFactory.visual(MeshFactory.cylinder(0.46, wall_h, 16, 0.7), PBRLibrary.trim(theme), "CornerCol")
		col.position = origin + offset + Vector3(0, wall_h * 0.5, 0)
		col.set_meta("asset_socket", "corner")
		parent.add_child(col)


static func niches(parent: Node3D, origin: Vector3, room: RoomSpec, theme: StringName, wall_h: float) -> void:
	var half := DD.ROOM_SIZE * 0.5 - 0.38
	var placements: Array[Dictionary] = []
	if not bool(room.doors.get("n", false)):
		placements.append({"pos": origin + Vector3(-2.1, 1.35, -half + 0.12), "yaw": 0.0})
	if not bool(room.doors.get("s", false)):
		placements.append({"pos": origin + Vector3(2.0, 1.35, half - 0.12), "yaw": PI})
	if not bool(room.doors.get("e", false)):
		placements.append({"pos": origin + Vector3(half - 0.12, 1.4, -1.6), "yaw": -PI * 0.5})
	if not bool(room.doors.get("w", false)):
		placements.append({"pos": origin + Vector3(-half + 0.12, 1.4, 1.4), "yaw": PI * 0.5})
	for spec in placements:
		var root := Node3D.new()
		root.name = "Niche"
		root.position = spec["pos"]
		root.rotation.y = spec["yaw"]
		root.set_meta("asset_socket", "niche")
		var recess := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.35, 1.7, 0.36), 0.05, 0.7), PBRLibrary.wear(theme), "NicheBack")
		root.add_child(recess)
		var frame := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.52, 1.88, 0.10), 0.04, 0.55), PBRLibrary.trim(theme), "NicheFrame")
		frame.position = Vector3(0, 0, 0.18)
		root.add_child(frame)
		var shelf := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.05, 0.07, 0.2), 0.015, 0.5), PBRLibrary.trim(theme), "NicheShelf")
		shelf.position = Vector3(0, -0.35, 0.04)
		root.add_child(shelf)
		parent.add_child(root)
	var wet := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.6, 1.1, 0.04), 0.01, 0.6), PBRLibrary.wet(theme), "Moisture")
	wet.position = origin + Vector3(-3.4, 0.55, -half + 0.22)
	parent.add_child(wet)
	if wall_h > 4.6:
		var wet2 := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.2, 0.8, 0.04), 0.01, 0.6), PBRLibrary.wet(theme), "Moisture")
		wet2.position = origin + Vector3(3.2, 0.7, half - 0.22)
		parent.add_child(wet2)


static func wall_run(parent: Node3D, center: Vector3, size: Vector3, has_door: bool, theme: StringName, dir: String) -> void:
	if not has_door:
		_paneled_wall(parent, center, size, theme, dir)
		return

	var axis_x := dir == "n" or dir == "s"
	if axis_x:
		var wing := (size.x - DD.DOOR_WIDTH) * 0.5
		_wing(parent, center + Vector3(-(DD.DOOR_WIDTH * 0.5 + wing * 0.5), 0, 0), Vector3(wing, size.y, size.z), theme, dir)
		_wing(parent, center + Vector3(DD.DOOR_WIDTH * 0.5 + wing * 0.5, 0, 0), Vector3(wing, size.y, size.z), theme, dir)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := slab(Vector3(DD.DOOR_WIDTH, lintel_h, size.z), PBRLibrary.wall(theme), "wall", 1.0)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)
	else:
		var wing := (size.z - DD.DOOR_WIDTH) * 0.5
		_wing(parent, center + Vector3(0, 0, -(DD.DOOR_WIDTH * 0.5 + wing * 0.5)), Vector3(size.x, size.y, wing), theme, dir)
		_wing(parent, center + Vector3(0, 0, DD.DOOR_WIDTH * 0.5 + wing * 0.5), Vector3(size.x, size.y, wing), theme, dir)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := slab(Vector3(size.x, lintel_h, DD.DOOR_WIDTH), PBRLibrary.wall(theme), "wall", 1.0)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)
	_door_frame(parent, center, size, theme, axis_x)
	_arch(parent, center, size, theme, dir)


static func pillars(parent: Node3D, origin: Vector3, theme: StringName, wall_h: float = DD.WALL_HEIGHT) -> void:
	var inset := DD.ROOM_SIZE * 0.5 - 3.35
	for offset in [Vector3(inset, 0, inset), Vector3(-inset, 0, inset), Vector3(inset, 0, -inset), Vector3(-inset, 0, -inset)]:
		var authored := AssetLibrary.instance(AssetLibrary.kit_path("pillar"))
		var pillar: Node3D
		if authored:
			pillar = authored
			pillar.name = "pillar"
			_paint_tree(pillar, PBRLibrary.trim(theme))
			pillar.position = origin + offset
			pillar.scale = Vector3(1.0, wall_h / 4.0, 1.0)
		else:
			pillar = MeshFactory.visual(MeshFactory.cylinder(0.18, wall_h, 12, 0.7), PBRLibrary.trim(theme), "pillar")
			pillar.position = origin + offset + Vector3(0, wall_h * 0.5, 0)
		parent.add_child(pillar)


static func beams(parent: Node3D, origin: Vector3, theme: StringName, wall_h: float = DD.WALL_HEIGHT) -> void:
	if theme == &"cavern":
		return
	for i in range(-2, 3):
		var beam := _authored_or_mesh(
			AssetLibrary.kit_path("beam"),
			MeshFactory.beveled_box(Vector3(DD.ROOM_SIZE - 0.6, 0.16, 0.22), 0.02, 0.8),
			PBRLibrary.wood(),
			"beam"
		)
		beam.position = origin + Vector3(0, wall_h - 0.22, float(i) * 2.6)
		parent.add_child(beam)


static func place_prop(parent: Node3D, pos: Vector3, kind: String, theme: StringName) -> void:
	_place_prop(parent, pos, kind, theme)


static func decorate(parent: Node3D, origin: Vector3, room: RoomSpec, theme: StringName) -> void:
	var seed_hash := int(origin.x * 17.0 + origin.z * 31.0) + int(room.kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash if seed_hash != 0 else 1
	_floor_dressing(parent, origin, theme, rng)
	if room.kind == DD.RoomKind.START:
		_place_prop(parent, origin + Vector3(3.8, 0.0, 3.2), "bones", theme)
		_place_prop(parent, origin + Vector3(3.6, 0.0, -2.8), "barrel", theme)
		banner_at(parent, origin + Vector3(-4.6, 2.15, -5.8), theme, Color(0.28, 0.12, 0.18))
	elif room.kind == DD.RoomKind.BOSS:
		_place_prop(parent, origin + Vector3(-4.0, 0.0, 3.4), "chain", theme)
		_place_prop(parent, origin + Vector3(4.1, 0.0, 3.2), "chain", theme)
		_place_prop(parent, origin + Vector3(-3.6, 0.0, -3.5), "bones", theme)
		banner_at(parent, origin + Vector3(-5.4, 2.2, 0.0), theme, Color(0.18, 0.10, 0.28), true)
		banner_at(parent, origin + Vector3(5.4, 2.2, 0.0), theme, Color(0.18, 0.10, 0.28), true)
	else:
		if rng.randf() < 0.7:
			_place_prop(parent, origin + Vector3(rng.randf_range(-4.2, -2.4), 0.0, rng.randf_range(2.2, 4.0)), "barrel", theme)
		if rng.randf() < 0.55:
			_place_prop(parent, origin + Vector3(rng.randf_range(2.4, 4.2), 0.0, rng.randf_range(-4.0, -2.2)), "bones", theme)
		if rng.randf() < 0.4:
			_place_prop(parent, origin + Vector3(rng.randf_range(-1.5, 1.5), 2.4, rng.randf_range(-4.4, -3.8)), "chain", theme)
		if rng.randf() < 0.5:
			banner_at(parent, origin + Vector3(rng.randf_range(-5.2, 5.2), 2.2, -5.9), theme, _banner_color(theme, rng))


static func torch_at(parent: Node3D, position: Vector3, cast_shadow: bool) -> void:
	var root := Node3D.new()
	root.name = "Torch"
	root.position = position
	root.set_meta("asset_socket", "torch")
	var authored := AssetLibrary.instance(AssetLibrary.prop_path("torch"))
	if authored:
		authored.name = "BodyVisual"
		_paint_tree(authored, PBRLibrary.metal())
		root.add_child(authored)
	else:
		var bracket := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.08, 0.28, 0.08), 0.01, 0.4), PBRLibrary.metal(), "BodyVisual")
		bracket.position = Vector3(0, 0.1, 0)
		root.add_child(bracket)
		var shaft := MeshFactory.visual(MeshFactory.cylinder(0.035, 0.55, 8, 0.4), PBRLibrary.wood(), "Shaft")
		shaft.position = Vector3(0, 0.42, 0.04)
		root.add_child(shaft)
		var bowl := MeshFactory.visual(MeshFactory.cylinder(0.07, 0.08, 8, 0.3), PBRLibrary.metal(), "Bowl")
		bowl.position = Vector3(0, 0.7, 0.04)
		root.add_child(bowl)
		var flame := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.06, 0.16, 0.06), 0.01, 0.3), PBRLibrary.emissive(Color(1.0, 0.45, 0.12), 3.4), "Flame")
		flame.position = Vector3(0, 0.84, 0.04)
		root.add_child(flame)
	var light := TorchLight.new()
	light.position = Vector3(0, 0.88, 0.08)
	light.base_energy = 5.0 if cast_shadow else 2.6
	light.omni_range = 8.2 if cast_shadow else 5.8
	VisualLook.configure_omni(light, cast_shadow)
	root.add_child(light)
	parent.add_child(root)


static func wall_torches(parent: Node3D, origin: Vector3, room: RoomSpec, theme: StringName, wall_h: float = DD.WALL_HEIGHT) -> void:
	var half := DD.ROOM_SIZE * 0.5 - 0.38
	var height := minf(2.25, wall_h * 0.55)
	var placements: Array[Vector3] = []
	if not bool(room.doors.get("n", false)):
		placements.append(origin + Vector3(-2.8, height, -half))
		placements.append(origin + Vector3(2.8, height, -half))
	if not bool(room.doors.get("s", false)):
		placements.append(origin + Vector3(2.6, height, half))
	if not bool(room.doors.get("e", false)):
		placements.append(origin + Vector3(half, height, 0.0))
	if not bool(room.doors.get("w", false)):
		placements.append(origin + Vector3(-half, height, -1.4))
	if placements.is_empty():
		placements.append(origin + Vector3(0, height, -half + 0.2))
	var key_idx := 0
	for i in placements.size():
		torch_at(parent, placements[i], i == key_idx)
	if theme == &"cavern":
		var drip := MeshFactory.visual(MeshFactory.cylinder(0.09, 0.7, 8, 0.5), PBRLibrary.wall(theme), "Stal")
		drip.position = origin + Vector3(2.1, wall_h - 0.4, 1.8)
		parent.add_child(drip)
		var drip2 := MeshFactory.visual(MeshFactory.cylinder(0.12, 1.05, 8, 0.5), PBRLibrary.wall(theme), "Stal")
		drip2.position = origin + Vector3(-2.4, wall_h - 0.55, -1.6)
		parent.add_child(drip2)


static func chest_visual() -> Node3D:
	var authored := AssetLibrary.instance(AssetLibrary.prop_path("chest"))
	if authored:
		authored.name = "BodyVisual"
		authored.set_meta("asset_socket", "chest")
		_paint_tree(authored, PBRLibrary.wood())
		return authored
	var root := Node3D.new()
	root.name = "BodyVisual"
	root.set_meta("asset_socket", "chest")
	var box := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.95, 0.55, 0.62), 0.03, 0.6), PBRLibrary.wood())
	box.position = Vector3(0, 0.28, 0)
	root.add_child(box)
	var lid := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.98, 0.12, 0.66), 0.02, 0.6), PBRLibrary.wood())
	lid.position = Vector3(0, 0.6, 0)
	root.add_child(lid)
	var band := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.0, 0.06, 0.68), 0.01, 0.4), PBRLibrary.metal())
	band.position = Vector3(0, 0.32, 0)
	root.add_child(band)
	return root


static func gate_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "BodyVisual"
	root.set_meta("asset_socket", "exit")
	var frame := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.8, 2.7, 0.22), 0.04, 0.7), PBRLibrary.metal())
	frame.position = Vector3(0, 1.35, 0)
	root.add_child(frame)
	var glow := MeshFactory.visual(MeshFactory.beveled_box(Vector3(1.15, 2.1, 0.08), 0.02, 0.5), PBRLibrary.emissive(Color(0.35, 0.95, 0.7), 2.2), "Glow")
	glow.position = Vector3(0, 1.3, 0.02)
	root.add_child(glow)
	return root


static func banner_at(parent: Node3D, pos: Vector3, theme: StringName, color: Color, rotate_y90: bool = false) -> void:
	var root := Node3D.new()
	root.name = "Banner"
	root.position = pos
	if rotate_y90:
		root.rotation_degrees = Vector3(0, 90, 0)
	var rod := MeshFactory.visual(MeshFactory.cylinder(0.03, 0.95, 8, 0.4), PBRLibrary.wood(), "Rod")
	rod.rotation_degrees = Vector3(0, 0, 90)
	rod.position = Vector3(0, 0.55, 0)
	root.add_child(rod)
	var cloth := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.72, 1.15, 0.03), 0.01, 0.5), PBRLibrary.cloth(color), "Cloth")
	cloth.position = Vector3(0, -0.12, 0.02)
	root.add_child(cloth)
	var tip := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.18, 0.16, 0.03), 0.01, 0.3), PBRLibrary.cloth(color.darkened(0.15)), "Tip")
	tip.position = Vector3(0, -0.78, 0.02)
	root.add_child(tip)
	var trim := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.76, 0.04, 0.04), 0.008, 0.3), PBRLibrary.metal(), "Band")
	trim.position = Vector3(0, 0.52, 0.02)
	root.add_child(trim)
	parent.add_child(root)


static func puddle_at(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var puddle := MeshFactory.visual(MeshFactory.beveled_box(Vector3(size.x, 0.012, size.z), 0.004, 1.0), PBRLibrary.puddle(), "Puddle")
	puddle.position = pos + Vector3(0, 0.02, 0)
	parent.add_child(puddle)


static func debris_at(parent: Node3D, pos: Vector3, theme: StringName, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Debris"
	root.position = pos
	for i in range(rng.randi_range(3, 5)):
		var chip := MeshFactory.visual(
			MeshFactory.beveled_box(Vector3(rng.randf_range(0.12, 0.32), rng.randf_range(0.05, 0.14), rng.randf_range(0.1, 0.26)), 0.015, 0.5),
			PBRLibrary.wear(theme),
			"Chip%d" % i
		)
		chip.position = Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(0.03, 0.08), rng.randf_range(-0.22, 0.22))
		chip.rotation_degrees = Vector3(rng.randf_range(-18, 18), rng.randf_range(0, 180), rng.randf_range(-12, 12))
		root.add_child(chip)
	parent.add_child(root)


static func fog_shaft(parent: Node3D, pos: Vector3, height: float = 3.8) -> void:
	var root := Node3D.new()
	root.name = "FogShaft"
	root.position = pos
	var cone := MeshInstance3D.new()
	cone.name = "Volume"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.95
	mesh.height = height
	mesh.radial_segments = 12
	cone.mesh = mesh
	cone.material_override = PBRLibrary.shaft()
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.position = Vector3(0, height * 0.5, 0)
	root.add_child(cone)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.82, 0.52)
	spot.light_energy = 3.4
	spot.spot_range = height + 1.4
	spot.spot_angle = 18.0
	spot.spot_attenuation = 0.7
	spot.shadow_enabled = false
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.position = Vector3(0, height + 0.15, 0)
	root.add_child(spot)
	if not VisualLook.is_headless():
		var dust := GPUParticles3D.new()
		dust.amount = 28
		dust.lifetime = 3.2
		dust.preprocess = 1.0
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 12.0
		mat.initial_velocity_min = 0.05
		mat.initial_velocity_max = 0.22
		mat.gravity = Vector3(0, -0.12, 0)
		mat.scale_min = 0.015
		mat.scale_max = 0.04
		mat.color = Color(0.9, 0.82, 0.62, 0.35)
		dust.process_material = mat
		var draw := SphereMesh.new()
		draw.radius = 0.02
		draw.height = 0.04
		var mote := StandardMaterial3D.new()
		mote.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mote.albedo_color = Color(0.95, 0.88, 0.7, 0.35)
		mote.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw.material = mote
		dust.draw_pass_1 = draw
		dust.position = Vector3(0, height * 0.55, 0)
		root.add_child(dust)
	parent.add_child(root)


static func hall_embers(parent: Node3D, pos: Vector3) -> void:
	if VisualLook.is_headless():
		return
	var dust := GPUParticles3D.new()
	dust.name = "HallEmbers"
	dust.position = pos
	dust.amount = 40
	dust.lifetime = 2.8
	dust.preprocess = 1.2
	dust.visibility_aabb = AABB(Vector3(-4, -1, -8), Vector3(8, 4, 16))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(2.4, 0.4, 6.0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 28.0
	mat.initial_velocity_min = 0.15
	mat.initial_velocity_max = 0.55
	mat.gravity = Vector3(0, 0.18, 0)
	mat.scale_min = 0.012
	mat.scale_max = 0.035
	mat.color = Color(1.0, 0.5, 0.16, 0.8)
	dust.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.018
	draw.height = 0.036
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.albedo_color = Color(1.0, 0.45, 0.12)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.4, 0.08)
	ember_mat.emission_energy_multiplier = 3.5
	draw.material = ember_mat
	dust.draw_pass_1 = draw
	parent.add_child(dust)


static func _paneled_wall(parent: Node3D, center: Vector3, size: Vector3, theme: StringName, dir: String) -> void:
	var body := collider(size, "wall")
	body.position = center
	parent.add_child(body)
	var axis_x := dir == "n" or dir == "s"
	var length := size.x if axis_x else size.z
	var panels := 3 if length > 8.0 else 2
	var panel_len := length / float(panels)
	var inward := Vector3(0, 0, 0.045) if dir == "n" else Vector3(0, 0, -0.045) if dir == "s" else Vector3(-0.045, 0, 0) if dir == "e" else Vector3(0.045, 0, 0)
	for i in panels:
		var t := (float(i) + 0.5) / float(panels) - 0.5
		var offset := Vector3(t * length, 0, 0) if axis_x else Vector3(0, 0, t * length)
		var depth_jitter := 0.025 if i % 2 == 0 else -0.02
		var panel_size := Vector3(panel_len - 0.16, size.y - 0.08, size.z) if axis_x else Vector3(size.x, size.y - 0.08, panel_len - 0.16)
		var panel := MeshFactory.visual(MeshFactory.beveled_box(panel_size, 0.04, 1.0), PBRLibrary.wall(theme), "WallPanel")
		panel.position = center + offset + inward * (1.0 + depth_jitter * 8.0)
		parent.add_child(panel)
		if i < panels - 1:
			var pil_off := Vector3((float(i + 1) / float(panels) - 0.5) * length, 0, 0) if axis_x else Vector3(0, 0, (float(i + 1) / float(panels) - 0.5) * length)
			var pil_size := Vector3(0.22, size.y, size.z + 0.1) if axis_x else Vector3(size.x + 0.1, size.y, 0.22)
			var pilaster := MeshFactory.visual(MeshFactory.beveled_box(pil_size, 0.03, 0.7), PBRLibrary.trim(theme), "Pilaster")
			pilaster.position = center + pil_off + inward * 1.4
			parent.add_child(pilaster)
	_add_trim(parent, center, size, theme, dir, false)
	var wear := MeshFactory.visual(
		MeshFactory.beveled_box(Vector3(size.x, 0.12, size.z + 0.06) if axis_x else Vector3(size.x + 0.06, 0.12, size.z), 0.015, 0.6),
		PBRLibrary.wear(theme),
		"Wear"
	)
	wear.position = center + Vector3(0, -size.y * 0.5 + 0.22, 0) + inward
	parent.add_child(wear)


static func _wing(parent: Node3D, pos: Vector3, size: Vector3, theme: StringName, dir: String) -> void:
	_paneled_wall(parent, pos, size, theme, dir)


static func _add_trim(parent: Node3D, center: Vector3, size: Vector3, theme: StringName, dir: String, doorway: bool) -> void:
	var axis_x := dir == "n" or dir == "s"
	var base_size := Vector3(size.x, 0.18, size.z + 0.08) if axis_x else Vector3(size.x + 0.08, 0.18, size.z)
	if doorway:
		base_size = Vector3(size.x, 0.18, size.z + 0.06) if axis_x else Vector3(size.x + 0.06, 0.18, size.z)
	var base := MeshFactory.visual(MeshFactory.beveled_box(base_size, 0.02, 0.55), PBRLibrary.trim(theme), "TrimBase")
	base.position = center + Vector3(0, -size.y * 0.5 + 0.09, 0)
	parent.add_child(base)
	var cornice := MeshFactory.visual(MeshFactory.beveled_box(base_size + Vector3(0, 0.04, 0), 0.02, 0.55), PBRLibrary.trim(theme), "TrimTop")
	cornice.position = center + Vector3(0, size.y * 0.5 - 0.1, 0)
	parent.add_child(cornice)


static func _door_frame(parent: Node3D, center: Vector3, size: Vector3, theme: StringName, axis_x: bool) -> void:
	var frame_size := Vector3(DD.DOOR_WIDTH + 0.22, 0.14, DD.WALL_THICKNESS + 0.18) if axis_x else Vector3(DD.WALL_THICKNESS + 0.18, 0.14, DD.DOOR_WIDTH + 0.22)
	var sill := MeshFactory.visual(MeshFactory.beveled_box(frame_size, 0.02, 0.45), PBRLibrary.trim(theme), "DoorSill")
	sill.position = center + Vector3(0, -size.y * 0.5 + 0.08, 0)
	parent.add_child(sill)
	var jamb := Vector3(0.16, DD.DOOR_HEIGHT, DD.WALL_THICKNESS + 0.12) if axis_x else Vector3(DD.WALL_THICKNESS + 0.12, DD.DOOR_HEIGHT, 0.16)
	var left := MeshFactory.visual(MeshFactory.beveled_box(jamb, 0.02, 0.5), PBRLibrary.trim(theme), "JambL")
	var right := MeshFactory.visual(MeshFactory.beveled_box(jamb, 0.02, 0.5), PBRLibrary.trim(theme), "JambR")
	if axis_x:
		left.position = center + Vector3(-DD.DOOR_WIDTH * 0.5, -size.y * 0.5 + DD.DOOR_HEIGHT * 0.5, 0)
		right.position = center + Vector3(DD.DOOR_WIDTH * 0.5, -size.y * 0.5 + DD.DOOR_HEIGHT * 0.5, 0)
	else:
		left.position = center + Vector3(0, -size.y * 0.5 + DD.DOOR_HEIGHT * 0.5, -DD.DOOR_WIDTH * 0.5)
		right.position = center + Vector3(0, -size.y * 0.5 + DD.DOOR_HEIGHT * 0.5, DD.DOOR_WIDTH * 0.5)
	parent.add_child(left)
	parent.add_child(right)


static func _arch(parent: Node3D, center: Vector3, size: Vector3, theme: StringName, dir: String) -> void:
	var node := MeshFactory.visual(
		MeshFactory.stone_arch(DD.DOOR_WIDTH + 0.7, 1.15, 0.52, 0.6),
		PBRLibrary.trim(theme),
		"Arch"
	)
	node.position = center + Vector3(0, -size.y * 0.5 + DD.DOOR_HEIGHT - 0.08, 0)
	if dir == "e" or dir == "w":
		node.rotation_degrees = Vector3(0, 90, 0)
	parent.add_child(node)
	var authored := AssetLibrary.instance(AssetLibrary.kit_path("arch"))
	if authored:
		authored.name = "KitArch"
		_paint_tree(authored, PBRLibrary.trim(theme))
		authored.position = node.position + Vector3(0, 0.18, 0)
		if dir == "e" or dir == "w":
			authored.rotation_degrees = Vector3(0, 90, 0)
		parent.add_child(authored)


static func _floor_dressing(parent: Node3D, origin: Vector3, theme: StringName, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.85:
		puddle_at(parent, origin + Vector3(rng.randf_range(-3.5, 3.5), 0.0, rng.randf_range(-3.5, 3.5)), Vector3(rng.randf_range(0.7, 1.5), 0.01, rng.randf_range(0.45, 1.1)))
	if rng.randf() < 0.55:
		puddle_at(parent, origin + Vector3(rng.randf_range(-4.2, 4.2), 0.0, rng.randf_range(-4.0, 4.0)), Vector3(rng.randf_range(0.45, 0.9), 0.01, rng.randf_range(0.3, 0.7)))
	debris_at(parent, origin + Vector3(rng.randf_range(-4.6, -2.2), 0.0, rng.randf_range(2.4, 4.6)), theme, rng)
	if rng.randf() < 0.6:
		debris_at(parent, origin + Vector3(rng.randf_range(2.2, 4.6), 0.0, rng.randf_range(-4.6, -2.4)), theme, rng)
	debris_at(parent, origin + Vector3(rng.randf_range(-1.8, 1.8), 0.0, rng.randf_range(-4.8, -3.6)), theme, rng)
	var rubble := MeshFactory.visual(
		MeshFactory.beveled_box(Vector3(rng.randf_range(0.55, 0.9), rng.randf_range(0.22, 0.38), rng.randf_range(0.4, 0.72)), 0.05, 0.55),
		PBRLibrary.wear(theme),
		"Rubble"
	)
	rubble.position = origin + Vector3(rng.randf_range(-3.2, -1.4), 0.14, rng.randf_range(-1.6, 1.6))
	rubble.rotation_degrees = Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 180), rng.randf_range(-8, 8))
	parent.add_child(rubble)
	if rng.randf() < 0.8:
		var rubble2 := MeshFactory.visual(
			MeshFactory.beveled_box(Vector3(rng.randf_range(0.4, 0.7), rng.randf_range(0.16, 0.3), rng.randf_range(0.32, 0.58)), 0.04, 0.55),
			PBRLibrary.wear(theme),
			"Rubble"
		)
		rubble2.position = origin + Vector3(rng.randf_range(1.2, 3.4), 0.12, rng.randf_range(-2.2, 2.2))
		rubble2.rotation_degrees = Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 180), rng.randf_range(-6, 6))
		parent.add_child(rubble2)


static func _banner_color(theme: StringName, rng: RandomNumberGenerator) -> Color:
	if theme == &"cavern":
		return Color(0.18, 0.28, 0.22) if rng.randf() < 0.5 else Color(0.32, 0.22, 0.12)
	return Color(0.28, 0.10, 0.16) if rng.randf() < 0.5 else Color(0.16, 0.14, 0.32)


static func _place_prop(parent: Node3D, pos: Vector3, kind: String, theme: StringName) -> void:
	var node := AssetLibrary.instance(AssetLibrary.prop_path(kind))
	if node == null:
		node = _fallback_prop(kind, theme)
	else:
		_paint_tree(node, _prop_material(kind, theme))
	node.position = pos
	node.set_meta("asset_socket", kind)
	if node.name == "Node3D" or node.name.is_empty():
		node.name = kind.capitalize()
	parent.add_child(node)


static func _prop_material(kind: String, theme: StringName) -> Material:
	match kind:
		"barrel", "chest":
			return PBRLibrary.wood()
		"chain":
			return PBRLibrary.metal()
		"bones":
			return PBRLibrary.bone()
		_:
			return PBRLibrary.wall(theme)


static func _paint_tree(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_paint_tree(child, material)


static func _fallback_prop(kind: String, theme: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	match kind:
		"barrel":
			var keg := MeshFactory.visual(MeshFactory.cylinder(0.32, 0.72, 12, 0.55), PBRLibrary.wood())
			keg.position = Vector3(0, 0.36, 0)
			root.add_child(keg)
			var hoop := MeshFactory.visual(MeshFactory.cylinder(0.34, 0.05, 12, 0.3), PBRLibrary.metal(), "Hoop")
			hoop.position = Vector3(0, 0.22, 0)
			root.add_child(hoop)
		"bones":
			var skull := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.28, 0.22, 0.32), 0.03, 0.4), PBRLibrary.bone())
			skull.position = Vector3(0, 0.16, 0)
			root.add_child(skull)
			var femur := MeshFactory.visual(MeshFactory.cylinder(0.04, 0.55, 6, 0.3), PBRLibrary.bone(), "Femur")
			femur.position = Vector3(0.18, 0.08, 0.12)
			femur.rotation_degrees = Vector3(0, 0, 72)
			root.add_child(femur)
		"chain":
			for i in 5:
				var link := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.08, 0.14, 0.04), 0.01, 0.25), PBRLibrary.metal(), "Link%d" % i)
				link.position = Vector3(0, 0.1 + float(i) * 0.16, 0)
				link.rotation_degrees = Vector3(0, 35 * (i % 2), 8)
				root.add_child(link)
		_:
			var rubble := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.4, 0.25, 0.4), 0.03, 0.5), PBRLibrary.wall(theme))
			rubble.position = Vector3(0, 0.12, 0)
			root.add_child(rubble)
	return root


static func _authored_or_mesh(path: String, mesh: Mesh, material: Material, name: String) -> Node3D:
	var authored := AssetLibrary.instance(path)
	if authored:
		authored.name = name
		_paint_tree(authored, material)
		return authored
	return MeshFactory.visual(mesh, material, name)


static func _overlay(body: Node, socket: String) -> void:
	var extra := AssetLibrary.instance(AssetLibrary.kit_path(socket))
	if extra:
		extra.name = "KitOverlay"
		body.add_child(extra)
