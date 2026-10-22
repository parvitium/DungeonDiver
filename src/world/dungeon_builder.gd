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
	VisualLook.attach_world(parent, def)

	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	parent.add_child(nav)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 1.7
	nav_mesh.agent_max_climb = 0.4
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.navigation_mesh = nav_mesh
	markers["nav"] = nav

	var theme := DungeonKit.theme_of(def)
	for room in blueprint.rooms:
		_build_room(nav, parent, room, def, theme, markers)

	if bake_nav and DisplayServer.get_name() != "headless":
		nav.bake_navigation_mesh(false)
	return markers


func _build_room(nav: NavigationRegion3D, parent: Node3D, room: RoomSpec, _def: DungeonTypeDef, theme: StringName, markers: Dictionary) -> void:
	var origin := room.world_origin()
	var half := DD.ROOM_SIZE * 0.5

	var floor_body := DungeonKit.slab(Vector3(DD.ROOM_SIZE, 0.35, DD.ROOM_SIZE), PBRLibrary.floor_mat(theme), "floor", 1.0)
	floor_body.position = origin + Vector3(0, -0.175, 0)
	nav.add_child(floor_body)

	var ceiling := DungeonKit.slab(Vector3(DD.ROOM_SIZE, 0.3, DD.ROOM_SIZE), PBRLibrary.ceiling(theme), "ceiling", 1.0)
	ceiling.position = origin + Vector3(0, DD.WALL_HEIGHT + 0.15, 0)
	parent.add_child(ceiling)

	DungeonKit.wall_run(parent, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, -half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(room.doors["n"]), theme, "n")
	DungeonKit.wall_run(parent, origin + Vector3(0, DD.WALL_HEIGHT * 0.5, half), Vector3(DD.ROOM_SIZE, DD.WALL_HEIGHT, DD.WALL_THICKNESS), bool(room.doors["s"]), theme, "s")
	DungeonKit.wall_run(parent, origin + Vector3(half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), bool(room.doors["e"]), theme, "e")
	DungeonKit.wall_run(parent, origin + Vector3(-half, DD.WALL_HEIGHT * 0.5, 0), Vector3(DD.WALL_THICKNESS, DD.WALL_HEIGHT, DD.ROOM_SIZE), bool(room.doors["w"]), theme, "w")

	DungeonKit.pillars(parent, origin, theme)
	DungeonKit.beams(parent, origin, theme)
	DungeonKit.wall_torches(parent, origin, room, theme)
	DungeonKit.decorate(parent, origin, room, theme)
	_room_key_light(parent, origin, room, _def)

	if room.kind == DD.RoomKind.START:
		markers["player"] = origin + Vector3(0, 0.05, 0)
		var plinth := DungeonKit.slab(Vector3(1.5, 0.4, 1.5), PBRLibrary.wood(), "plinth", 0.6)
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


func _room_key_light(parent: Node3D, origin: Vector3, room: RoomSpec, def: DungeonTypeDef) -> void:
	var key := OmniLight3D.new()
	key.name = "RoomKey"
	key.position = origin + Vector3(0, 2.55, 0)
	key.light_color = def.light_color.lerp(Color(1.0, 0.72, 0.42), 0.55) if def else Color(1.0, 0.7, 0.4)
	key.light_energy = 5.2 if room.kind == DD.RoomKind.BOSS else 3.8
	key.omni_range = 13.0
	key.omni_attenuation = 0.9
	VisualLook.configure_omni(key, room.kind == DD.RoomKind.START or room.kind == DD.RoomKind.BOSS)
	parent.add_child(key)
