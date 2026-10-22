class_name DungeonKit
extends RefCounted
## Modular dungeon pieces with collision, UVs, trim, and authored GLB overlays.


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
	var visual := MeshFactory.visual(MeshFactory.box(size, tile), material, "BodyVisual")
	body.add_child(visual)
	_overlay(body, socket)
	return body


static func wall_run(parent: Node3D, center: Vector3, size: Vector3, has_door: bool, theme: StringName, dir: String) -> void:
	if not has_door:
		var wall := slab(size, PBRLibrary.wall(theme), "wall", 1.05)
		wall.position = center
		parent.add_child(wall)
		_add_trim(parent, center, size, theme, dir, false)
		return

	var axis_x := dir == "n" or dir == "s"
	if axis_x:
		var wing := (size.x - DD.DOOR_WIDTH) * 0.5
		_wing(parent, center + Vector3(-(DD.DOOR_WIDTH * 0.5 + wing * 0.5), 0, 0), Vector3(wing, size.y, size.z), theme, dir)
		_wing(parent, center + Vector3(DD.DOOR_WIDTH * 0.5 + wing * 0.5, 0, 0), Vector3(wing, size.y, size.z), theme, dir)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := slab(Vector3(DD.DOOR_WIDTH, lintel_h, size.z), PBRLibrary.wall(theme), "wall", 1.05)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)
	else:
		var wing := (size.z - DD.DOOR_WIDTH) * 0.5
		_wing(parent, center + Vector3(0, 0, -(DD.DOOR_WIDTH * 0.5 + wing * 0.5)), Vector3(size.x, size.y, wing), theme, dir)
		_wing(parent, center + Vector3(0, 0, DD.DOOR_WIDTH * 0.5 + wing * 0.5), Vector3(size.x, size.y, wing), theme, dir)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := slab(Vector3(size.x, lintel_h, DD.DOOR_WIDTH), PBRLibrary.wall(theme), "wall", 1.05)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)
	_door_frame(parent, center, size, theme, axis_x)
	_arch(parent, center, theme, dir)


static func pillars(parent: Node3D, origin: Vector3, theme: StringName) -> void:
	var inset := DD.ROOM_SIZE * 0.5 - 0.85
	for offset in [Vector3(inset, 0, inset), Vector3(-inset, 0, inset), Vector3(inset, 0, -inset), Vector3(-inset, 0, -inset)]:
		var authored := AssetLibrary.instance(AssetLibrary.kit_path("pillar"))
		var pillar: Node3D
		if authored:
			pillar = authored
			pillar.name = "pillar"
			_paint_tree(pillar, PBRLibrary.trim(theme))
			pillar.position = origin + offset
			pillar.scale = Vector3(1.0, DD.WALL_HEIGHT / 4.0, 1.0)
		else:
			pillar = MeshFactory.visual(MeshFactory.box(Vector3(0.42, DD.WALL_HEIGHT, 0.42), 0.7), PBRLibrary.trim(theme), "pillar")
			pillar.position = origin + offset + Vector3(0, DD.WALL_HEIGHT * 0.5, 0)
		parent.add_child(pillar)


static func beams(parent: Node3D, origin: Vector3, theme: StringName) -> void:
	if theme == &"cavern":
		return
	for i in range(-2, 3):
		var beam := _authored_or_mesh(
			AssetLibrary.kit_path("beam"),
			MeshFactory.box(Vector3(DD.ROOM_SIZE - 0.6, 0.16, 0.22), 0.8),
			PBRLibrary.wood(),
			"beam"
		)
		beam.position = origin + Vector3(0, DD.WALL_HEIGHT - 0.22, float(i) * 2.6)
		parent.add_child(beam)


static func place_prop(parent: Node3D, pos: Vector3, kind: String, theme: StringName) -> void:
	_place_prop(parent, pos, kind, theme)


static func decorate(parent: Node3D, origin: Vector3, room: RoomSpec, theme: StringName) -> void:
	var seed_hash := int(origin.x * 17.0 + origin.z * 31.0) + int(room.kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash if seed_hash != 0 else 1
	if room.kind == DD.RoomKind.START:
		_place_prop(parent, origin + Vector3(3.8, 0.0, 3.2), "bones", theme)
		_place_prop(parent, origin + Vector3(3.6, 0.0, -2.8), "barrel", theme)
	elif room.kind == DD.RoomKind.BOSS:
		_place_prop(parent, origin + Vector3(-4.0, 0.0, 3.4), "chain", theme)
		_place_prop(parent, origin + Vector3(4.1, 0.0, 3.2), "chain", theme)
		_place_prop(parent, origin + Vector3(-3.6, 0.0, -3.5), "bones", theme)
	else:
		if rng.randf() < 0.7:
			_place_prop(parent, origin + Vector3(rng.randf_range(-4.2, -2.4), 0.0, rng.randf_range(2.2, 4.0)), "barrel", theme)
		if rng.randf() < 0.55:
			_place_prop(parent, origin + Vector3(rng.randf_range(2.4, 4.2), 0.0, rng.randf_range(-4.0, -2.2)), "bones", theme)
		if rng.randf() < 0.4:
			_place_prop(parent, origin + Vector3(rng.randf_range(-1.5, 1.5), 2.4, rng.randf_range(-4.4, -3.8)), "chain", theme)


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
		var bracket := MeshFactory.visual(MeshFactory.box(Vector3(0.08, 0.28, 0.08), 0.4), PBRLibrary.metal(), "BodyVisual")
		bracket.position = Vector3(0, 0.1, 0)
		root.add_child(bracket)
		var shaft := MeshFactory.visual(MeshFactory.cylinder(0.035, 0.55, 8, 0.4), PBRLibrary.wood(), "Shaft")
		shaft.position = Vector3(0, 0.42, 0.04)
		root.add_child(shaft)
		var bowl := MeshFactory.visual(MeshFactory.cylinder(0.07, 0.08, 8, 0.3), PBRLibrary.metal(), "Bowl")
		bowl.position = Vector3(0, 0.7, 0.04)
		root.add_child(bowl)
		var flame := MeshFactory.visual(MeshFactory.box(Vector3(0.06, 0.16, 0.06), 0.3), PBRLibrary.emissive(Color(1.0, 0.45, 0.12), 3.4), "Flame")
		flame.position = Vector3(0, 0.84, 0.04)
		root.add_child(flame)
	var light := TorchLight.new()
	light.position = Vector3(0, 0.88, 0.08)
	light.base_energy = 3.4 if cast_shadow else 1.55
	light.omni_range = 11.0 if cast_shadow else 6.5
	VisualLook.configure_omni(light, cast_shadow)
	root.add_child(light)
	parent.add_child(root)


static func wall_torches(parent: Node3D, origin: Vector3, room: RoomSpec, theme: StringName) -> void:
	var half := DD.ROOM_SIZE * 0.5 - 0.38
	var height := 2.25
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
		placements.append(origin + Vector3(0, height, 0))
	var key_idx := 0
	if room.kind == DD.RoomKind.BOSS or room.kind == DD.RoomKind.START:
		key_idx = 0
	for i in placements.size():
		torch_at(parent, placements[i], i == key_idx)
	if theme == &"cavern":
		var drip := MeshFactory.visual(MeshFactory.cylinder(0.09, 0.7, 8, 0.5), PBRLibrary.wall(theme), "Stal")
		drip.position = origin + Vector3(2.1, DD.WALL_HEIGHT - 0.4, 1.8)
		parent.add_child(drip)


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
	var box := MeshFactory.visual(MeshFactory.box(Vector3(0.95, 0.55, 0.62), 0.6), PBRLibrary.wood())
	box.position = Vector3(0, 0.28, 0)
	root.add_child(box)
	var lid := MeshFactory.visual(MeshFactory.box(Vector3(0.98, 0.12, 0.66), 0.6), PBRLibrary.wood())
	lid.position = Vector3(0, 0.6, 0)
	root.add_child(lid)
	var band := MeshFactory.visual(MeshFactory.box(Vector3(1.0, 0.06, 0.68), 0.4), PBRLibrary.metal())
	band.position = Vector3(0, 0.32, 0)
	root.add_child(band)
	return root


static func gate_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "BodyVisual"
	root.set_meta("asset_socket", "exit")
	var frame := MeshFactory.visual(MeshFactory.box(Vector3(1.8, 2.7, 0.22), 0.7), PBRLibrary.metal())
	frame.position = Vector3(0, 1.35, 0)
	root.add_child(frame)
	var glow := MeshFactory.visual(MeshFactory.box(Vector3(1.15, 2.1, 0.08), 0.5), PBRLibrary.emissive(Color(0.35, 0.95, 0.7), 2.2), "Glow")
	glow.position = Vector3(0, 1.3, 0.02)
	root.add_child(glow)
	return root


static func _wing(parent: Node3D, pos: Vector3, size: Vector3, theme: StringName, dir: String) -> void:
	var wall := slab(size, PBRLibrary.wall(theme), "wall", 1.05)
	wall.position = pos
	parent.add_child(wall)
	_add_trim(parent, pos, size, theme, dir, true)


static func _add_trim(parent: Node3D, center: Vector3, size: Vector3, theme: StringName, dir: String, doorway: bool) -> void:
	var axis_x := dir == "n" or dir == "s"
	var base_size := Vector3(size.x, 0.18, size.z + 0.08) if axis_x else Vector3(size.x + 0.08, 0.18, size.z)
	if doorway:
		base_size = Vector3(size.x, 0.18, size.z + 0.06) if axis_x else Vector3(size.x + 0.06, 0.18, size.z)
	var base := MeshFactory.visual(MeshFactory.box(base_size, 0.55), PBRLibrary.trim(theme), "TrimBase")
	base.position = center + Vector3(0, -size.y * 0.5 + 0.09, 0)
	parent.add_child(base)
	var cornice := MeshFactory.visual(MeshFactory.box(base_size + Vector3(0, 0.04, 0), 0.55), PBRLibrary.trim(theme), "TrimTop")
	cornice.position = center + Vector3(0, size.y * 0.5 - 0.1, 0)
	parent.add_child(cornice)


static func _door_frame(parent: Node3D, center: Vector3, size: Vector3, theme: StringName, axis_x: bool) -> void:
	var frame_size := Vector3(DD.DOOR_WIDTH + 0.22, 0.14, DD.WALL_THICKNESS + 0.18) if axis_x else Vector3(DD.WALL_THICKNESS + 0.18, 0.14, DD.DOOR_WIDTH + 0.22)
	var sill := MeshFactory.visual(MeshFactory.box(frame_size, 0.45), PBRLibrary.trim(theme), "DoorSill")
	sill.position = center + Vector3(0, -size.y * 0.5 + 0.08, 0)
	parent.add_child(sill)


static func _arch(parent: Node3D, center: Vector3, theme: StringName, dir: String) -> void:
	var authored := AssetLibrary.instance(AssetLibrary.kit_path("arch"))
	var node: Node3D
	if authored:
		node = authored
		node.name = "Arch"
		_paint_tree(node, PBRLibrary.trim(theme))
	else:
		node = MeshFactory.visual(MeshFactory.box(Vector3(3.15, 0.28, 0.55), 0.6), PBRLibrary.trim(theme), "Arch")
	node.position = center + Vector3(0, DD.DOOR_HEIGHT - DD.WALL_HEIGHT * 0.5 + 0.08, 0)
	if dir == "e" or dir == "w":
		node.rotation_degrees = Vector3(0, 90, 0)
	parent.add_child(node)


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
			var skull := MeshFactory.visual(MeshFactory.box(Vector3(0.28, 0.22, 0.32), 0.4), PBRLibrary.bone())
			skull.position = Vector3(0, 0.16, 0)
			root.add_child(skull)
			var femur := MeshFactory.visual(MeshFactory.cylinder(0.04, 0.55, 6, 0.3), PBRLibrary.bone(), "Femur")
			femur.position = Vector3(0.18, 0.08, 0.12)
			femur.rotation_degrees = Vector3(0, 0, 72)
			root.add_child(femur)
		"chain":
			for i in 5:
				var link := MeshFactory.visual(MeshFactory.box(Vector3(0.08, 0.14, 0.04), 0.25), PBRLibrary.metal(), "Link%d" % i)
				link.position = Vector3(0, 0.1 + float(i) * 0.16, 0)
				link.rotation_degrees = Vector3(0, 35 * (i % 2), 8)
				root.add_child(link)
		_:
			var rubble := MeshFactory.visual(MeshFactory.box(Vector3(0.4, 0.25, 0.4), 0.5), PBRLibrary.wall(theme))
			rubble.position = Vector3(0, 0.12, 0)
			root.add_child(rubble)
	return root


static func _authored_or_mesh(path: String, mesh: Mesh, material: Material, name: String) -> Node3D:
	var authored := AssetLibrary.instance(path)
	if authored:
		authored.name = name
		_paint_tree(authored, material)
		return authored
	var visual := MeshFactory.visual(mesh, material, name)
	return visual


static func _overlay(body: Node, socket: String) -> void:
	var extra := AssetLibrary.instance(AssetLibrary.kit_path(socket))
	if extra:
		extra.name = "KitOverlay"
		body.add_child(extra)
