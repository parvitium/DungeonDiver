class_name DungeonBuilder
extends RefCounted


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
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 1.7
	nav_mesh.agent_max_climb = 0.4
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
	env.ambient_light_color = def.light_color.darkened(0.55)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = def.fog_color
	env.fog_density = 0.035
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = env
	parent.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = def.light_color
	sun.light_energy = 0.35
	sun.shadow_enabled = false
	parent.add_child(sun)


func _build_room(nav: NavigationRegion3D, parent: Node3D, room: RoomSpec, def: DungeonTypeDef, markers: Dictionary) -> void:
	var origin := room.world_origin()
	var half := DD.ROOM_SIZE * 0.5
	var floor_color := def.floor_color
	if room.kind == DD.RoomKind.START:
		floor_color = def.floor_color.lightened(0.08)
	elif room.kind == DD.RoomKind.BOSS:
		floor_color = def.floor_color.lerp(def.accent_color, 0.25)

	var floor_body := Greybox.make_box(Vector3(DD.ROOM_SIZE, 0.35, DD.ROOM_SIZE), floor_color)
	floor_body.position = origin + Vector3(0, -0.175, 0)
	floor_body.set_meta("asset_socket", "floor")
	nav.add_child(floor_body)

	var ceiling := Greybox.make_box(Vector3(DD.ROOM_SIZE, 0.3, DD.ROOM_SIZE), def.wall_color.darkened(0.2))
	ceiling.position = origin + Vector3(0, DD.WALL_HEIGHT + 0.15, 0)
	ceiling.set_meta("asset_socket", "ceiling")
	parent.add_child(ceiling)

	_wall_with_door(parent, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, -half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(room.doors["n"]), def, "n")
	_wall_with_door(parent, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(room.doors["s"]), def, "s")
	_wall_with_door(parent, origin + Vector3(half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), bool(room.doors["e"]), def, "e")
	_wall_with_door(parent, origin + Vector3(-half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), bool(room.doors["w"]), def, "w")

	var lamp := OmniLight3D.new()
	lamp.position = origin + Vector3(0, 2.8, 0)
	lamp.light_color = def.light_color
	lamp.light_energy = 1.6 if room.kind == DD.RoomKind.BOSS else 1.15
	lamp.omni_range = 11.0
	parent.add_child(lamp)

	if room.kind == DD.RoomKind.START:
		markers["player"] = origin + Vector3(0, 0.05, 0)
		var plinth := Greybox.make_box(Vector3(1.4, 0.35, 1.4), def.accent_color)
		plinth.position = origin + Vector3(-3.5, 0.2, -3.5)
		parent.add_child(plinth)
	else:
		var offsets := [Vector3(3, 0, 2), Vector3(-3, 0, -2), Vector3(2.5, 0, -3)]
		for i in room.monster_ids.size():
			markers["spawns"].append({
				"id": room.monster_ids[i],
				"position": origin + offsets[i % offsets.size()] + Vector3(0, 0.05, 0),
			})

	if room.has_chest:
		markers["chests"].append(origin + Vector3(3.4, 0.45, -3.2))

	if room.has_exit:
		markers["exit"] = origin + Vector3(0, 0.1, 3.6)


func _wall_with_door(parent: Node3D, center: Vector3, size: Vector3, has_door: bool, def: DungeonTypeDef, dir: String) -> void:
	if not has_door:
		var wall := Greybox.make_box(size, def.wall_color)
		wall.position = center
		wall.set_meta("asset_socket", "wall")
		parent.add_child(wall)
		return

	var axis_x := dir == "n" or dir == "s"
	if axis_x:
		var wing := (size.x - DD.DOOR_WIDTH) * 0.5
		var left := Greybox.make_box(Vector3(wing, size.y, size.z), def.wall_color)
		left.position = center + Vector3(-(DD.DOOR_WIDTH * 0.5 + wing * 0.5), 0, 0)
		parent.add_child(left)
		var right := Greybox.make_box(Vector3(wing, size.y, size.z), def.wall_color)
		right.position = center + Vector3(DD.DOOR_WIDTH * 0.5 + wing * 0.5, 0, 0)
		parent.add_child(right)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := Greybox.make_box(Vector3(DD.DOOR_WIDTH, lintel_h, size.z), def.wall_color)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)
	else:
		var wing := (size.z - DD.DOOR_WIDTH) * 0.5
		var left := Greybox.make_box(Vector3(size.x, size.y, wing), def.wall_color)
		left.position = center + Vector3(0, 0, -(DD.DOOR_WIDTH * 0.5 + wing * 0.5))
		parent.add_child(left)
		var right := Greybox.make_box(Vector3(size.x, size.y, wing), def.wall_color)
		right.position = center + Vector3(0, 0, DD.DOOR_WIDTH * 0.5 + wing * 0.5)
		parent.add_child(right)
		var lintel_h := size.y - DD.DOOR_HEIGHT
		if lintel_h > 0.05:
			var lintel := Greybox.make_box(Vector3(size.x, lintel_h, DD.DOOR_WIDTH), def.wall_color)
			lintel.position = center + Vector3(0, (size.y - lintel_h) * 0.5, 0)
			parent.add_child(lintel)

	var frame := Greybox.make_box(
		Vector3(DD.DOOR_WIDTH + 0.15, 0.12, DD.WALL_THICKNESS + 0.12) if axis_x else Vector3(DD.WALL_THICKNESS + 0.12, 0.12, DD.DOOR_WIDTH + 0.15),
		def.accent_color,
		false
	)
	frame.position = center + Vector3(0, -size.y * 0.5 + 0.08, 0)
	parent.add_child(frame)
