class_name DungeonBuilder
extends RefCounted


static func exit_placement(origin: Vector3, room: RoomSpec) -> Dictionary:
	var half := DD.ROOM_SIZE * 0.5
	var inset := 0.42
	if not bool(room.doors.get("s", false)):
		return {"position": origin + Vector3(0, 0, half - inset), "inward": Vector3(0, 0, -1)}
	if not bool(room.doors.get("n", false)):
		return {"position": origin + Vector3(0, 0, -(half - inset)), "inward": Vector3(0, 0, 1)}
	if not bool(room.doors.get("e", false)):
		return {"position": origin + Vector3(half - inset, 0, 0), "inward": Vector3(-1, 0, 0)}
	return {"position": origin + Vector3(-(half - inset), 0, 0), "inward": Vector3(1, 0, 0)}


static func monster_spawn_offsets(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := maxi(count, 1)
	for i in count:
		var ang := TAU * float(i) / float(n) + 0.42
		var radius := 3.35 if count == 1 else 3.15 + 0.4 * float(i % 2)
		out.append(Vector3(cos(ang) * radius, 0.0, sin(ang) * radius))
	return out


func build(parent: Node3D, blueprint: DungeonBlueprint, def: DungeonTypeDef, bake_nav: bool = true) -> Dictionary:
	var markers := {
		"spawns": [],
		"chests": [],
		"exit": null,
		"player": Vector3.ZERO,
		"nav": null,
	}
	_environment(parent, def)

	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	parent.add_child(nav)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.7
	nav_mesh.agent_max_climb = 0.4
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav.navigation_mesh = nav_mesh
	markers["nav"] = nav

	for room in blueprint.rooms:
		_build_room(nav, parent, room, def, markers)

	if bake_nav and DisplayServer.get_name() != "headless":
		nav.bake_navigation_mesh(false)
	return markers


func _environment(parent: Node3D, def: DungeonTypeDef) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = def.fog_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = def.light_color.lerp(Color(0.55, 0.42, 0.32), 0.45).darkened(0.25)
	env.ambient_light_energy = 0.34
	env.fog_enabled = true
	env.fog_light_color = def.fog_color.lerp(Color(0.18, 0.1, 0.06), 0.35)
	env.fog_density = 0.022
	env.fog_aerial_perspective = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.12
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = def.fog_color.lerp(Color(0.4, 0.22, 0.1), 0.4)
	env.volumetric_fog_emission = def.light_color * 0.04
	env.volumetric_fog_length = 24.0
	world.environment = env
	parent.add_child(world)

	# Very dim fill so PBR albedo is readable without washing out torch light.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 28, 0)
	sun.light_color = def.light_color.lerp(Color(1.0, 0.82, 0.6), 0.5)
	sun.light_energy = 0.22
	sun.shadow_enabled = false
	parent.add_child(sun)


func _build_room(nav: NavigationRegion3D, parent: Node3D, room: RoomSpec, def: DungeonTypeDef, markers: Dictionary) -> void:
	var origin := room.world_origin()
	var half := DD.ROOM_SIZE * 0.5
	var floor_mat := DungeonMaterials.floor_mat(def)
	var wall_mat := DungeonMaterials.wall_mat(def)
	var ceil_mat := DungeonMaterials.ceiling_mat(def)

	var floor_body := Greybox.make_box_with_material(Vector3(DD.ROOM_SIZE, 0.35, DD.ROOM_SIZE), floor_mat)
	floor_body.position = origin + Vector3(0, -0.175, 0)
	floor_body.set_meta("asset_socket", "floor")
	nav.add_child(floor_body)

	var ceiling := Greybox.make_box_with_material(Vector3(DD.ROOM_SIZE, 0.3, DD.ROOM_SIZE), ceil_mat)
	ceiling.position = origin + Vector3(0, DD.WALL_HEIGHT + 0.15, 0)
	ceiling.set_meta("asset_socket", "ceiling")
	parent.add_child(ceiling)

	_wall_with_door(parent, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, -half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(room.doors["n"]), def, "n", wall_mat)
	_wall_with_door(parent, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(room.doors["s"]), def, "s", wall_mat)
	_wall_with_door(parent, origin + Vector3(half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), bool(room.doors["e"]), def, "e", wall_mat)
	_wall_with_door(parent, origin + Vector3(-half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), bool(room.doors["w"]), def, "w", wall_mat)

	var reserved: Array = []
	if room.kind == DD.RoomKind.START:
		markers["player"] = origin + Vector3(0, 0.05, 0)
		reserved.append(markers["player"])
		var plinth := Greybox.make_box_with_material(Vector3(1.4, 0.35, 1.4), wall_mat)
		plinth.position = origin + Vector3(-3.5, 0.2, -3.5)
		parent.add_child(plinth)
		reserved.append(plinth.position)
	else:
		var offsets := monster_spawn_offsets(room.monster_ids.size())
		for i in room.monster_ids.size():
			var spawn_at: Vector3 = origin + offsets[i] + Vector3(0, 0.05, 0)
			markers["spawns"].append({
				"id": room.monster_ids[i],
				"position": spawn_at,
			})
			reserved.append(spawn_at)

	if room.has_chest:
		var chest_at := origin + Vector3(3.4, 0.45, -3.2)
		markers["chests"].append(chest_at)
		reserved.append(chest_at)

	if room.has_exit:
		var exit_mark := exit_placement(origin, room)
		markers["exit"] = exit_mark
		reserved.append(exit_mark["position"])

	_place_torches(parent, origin, room, def)
	DungeonProps.dress_room(nav, parent, room, def, reserved)

	# Wood beams on the ceiling read as structure without blocking movement.
	if room.kind != DD.RoomKind.START:
		_ceiling_beams(parent, origin, def)


func _place_torches(parent: Node3D, origin: Vector3, room: RoomSpec, def: DungeonTypeDef) -> void:
	var half := DD.ROOM_SIZE * 0.5
	var inset := half - 0.38
	var warm := Color(1.0, 0.58, 0.22).lerp(def.light_color, 0.25)
	var dirs := {
		"n": {"pos": origin + Vector3(0, 1.72, -inset), "in": Vector3(0, 0, 1), "along": Vector3(1, 0, 0)},
		"s": {"pos": origin + Vector3(0, 1.72, inset), "in": Vector3(0, 0, -1), "along": Vector3(1, 0, 0)},
		"e": {"pos": origin + Vector3(inset, 1.72, 0), "in": Vector3(-1, 0, 0), "along": Vector3(0, 0, 1)},
		"w": {"pos": origin + Vector3(-inset, 1.72, 0), "in": Vector3(1, 0, 0), "along": Vector3(0, 0, 1)},
	}
	var want := 4 if room.kind == DD.RoomKind.BOSS else 2
	var used := 0
	var solid: Array = []
	var beside: Array = []
	for dir in ["n", "s", "e", "w"]:
		var data: Dictionary = dirs[dir]
		if bool(room.doors[dir]):
			beside.append({"pos": data["pos"] + data["along"] * 2.15, "in": data["in"]})
		else:
			solid.append({"pos": data["pos"], "in": data["in"]})
	var ordered: Array = solid + beside
	for i in mini(want, ordered.size()):
		var spot: Dictionary = ordered[i]
		DungeonProps.place_torch(parent, spot["pos"], spot["in"], warm, used == 0)
		used += 1


func _ceiling_beams(parent: Node3D, origin: Vector3, def: DungeonTypeDef) -> void:
	var wood := DungeonMaterials.wood_mat()
	for x_off in [-3.2, 0.0, 3.2]:
		var beam := Greybox.make_box_with_material(Vector3(0.28, 0.2, DD.ROOM_SIZE - 1.2), wood, false)
		beam.position = origin + Vector3(x_off, DD.WALL_HEIGHT - 0.22, 0)
		parent.add_child(beam)
	if String(def.id) == "crypt":
		var cross := Greybox.make_box_with_material(Vector3(DD.ROOM_SIZE - 1.2, 0.16, 0.24), wood, false)
		cross.position = origin + Vector3(0, DD.WALL_HEIGHT - 0.32, 0)
		parent.add_child(cross)


func _wall_with_door(parent: Node3D, center: Vector3, size: Vector3, has_door: bool, def: DungeonTypeDef, dir: String, wall_mat: Material) -> void:
	if not has_door:
		var wall := Greybox.make_box_with_material(size, wall_mat)
		wall.position = center
		wall.set_meta("asset_socket", "wall")
		parent.add_child(wall)
		return

	var axis_x := dir == "n" or dir == "s"
	if axis_x:
		var wing := (size.x - DD.DOOR_WIDTH) * 0.5
		var left := Greybox.make_box_with_material(Vector3(wing, size.y, size.z), wall_mat)
		left.position = center + Vector3(-(DD.DOOR_WIDTH * 0.5 + wing * 0.5), 0, 0)
		parent.add_child(left)
		var right := Greybox.make_box_with_material(Vector3(wing, size.y, size.z), wall_mat)
		right.position = center + Vector3(DD.DOOR_WIDTH * 0.5 + wing * 0.5, 0, 0)
		parent.add_child(right)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := Greybox.make_box_with_material(Vector3(DD.DOOR_WIDTH, lintel_h, size.z), wall_mat)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)
	else:
		var wing := (size.z - DD.DOOR_WIDTH) * 0.5
		var left := Greybox.make_box_with_material(Vector3(size.x, size.y, wing), wall_mat)
		left.position = center + Vector3(0, 0, -(DD.DOOR_WIDTH * 0.5 + wing * 0.5))
		parent.add_child(left)
		var right := Greybox.make_box_with_material(Vector3(size.x, size.y, wing), wall_mat)
		right.position = center + Vector3(0, 0, DD.DOOR_WIDTH * 0.5 + wing * 0.5)
		parent.add_child(right)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := Greybox.make_box_with_material(Vector3(size.x, lintel_h, DD.DOOR_WIDTH), wall_mat)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)

	var frame := Greybox.make_box_with_material(
		Vector3(DD.DOOR_WIDTH + 0.15, 0.12, DD.WALL_THICKNESS + 0.12) if axis_x else Vector3(DD.WALL_THICKNESS + 0.12, 0.12, DD.DOOR_WIDTH + 0.15),
		DungeonMaterials.wood_mat(),
		false
	)
	frame.position = center + Vector3(0, -size.y * 0.5 + 0.08, 0)
	parent.add_child(frame)
