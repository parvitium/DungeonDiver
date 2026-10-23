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
	var wall_h := room.wall_height()

	var floor_body := DungeonKit.flagstone_floor(Vector3(DD.ROOM_SIZE, 0.35, DD.ROOM_SIZE), theme, int(origin.x * 13.0 + origin.z * 29.0) + int(room.kind))
	floor_body.position = origin + Vector3(0, -0.175, 0)
	nav.add_child(floor_body)

	var ceiling := DungeonKit.vaulted_ceiling(Vector3(DD.ROOM_SIZE, 0.28, DD.ROOM_SIZE), theme, wall_h)
	ceiling.position = origin + Vector3(0, wall_h - 0.10, 0)
	parent.add_child(ceiling)

	DungeonKit.wall_run(parent, origin + Vector3(0, wall_h * 0.5, -half), Vector3(DD.ROOM_SIZE, wall_h, DD.WALL_THICKNESS), bool(room.doors["n"]), theme, "n")
	DungeonKit.wall_run(parent, origin + Vector3(0, wall_h * 0.5, half), Vector3(DD.ROOM_SIZE, wall_h, DD.WALL_THICKNESS), bool(room.doors["s"]), theme, "s")
	DungeonKit.wall_run(parent, origin + Vector3(half, wall_h * 0.5, 0), Vector3(DD.WALL_THICKNESS, wall_h, DD.ROOM_SIZE), bool(room.doors["e"]), theme, "e")
	DungeonKit.wall_run(parent, origin + Vector3(-half, wall_h * 0.5, 0), Vector3(DD.WALL_THICKNESS, wall_h, DD.ROOM_SIZE), bool(room.doors["w"]), theme, "w")

	DungeonKit.rounded_corners(parent, origin, theme, wall_h)
	DungeonKit.pillars(parent, origin, theme, wall_h)
	DungeonKit.beams(parent, origin, theme, wall_h)
	DungeonKit.wall_torches(parent, origin, room, theme, wall_h)
	DungeonKit.decorate(parent, origin, room, theme)
	DungeonKit.niches(parent, origin, room, theme, wall_h)
	_room_key_light(parent, origin, room, _def, wall_h)

	if room.kind == DD.RoomKind.START:
		markers["player"] = origin + room.spawn_offset()
		markers["player_yaw"] = room.facing_yaw()
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


func _room_key_light(parent: Node3D, origin: Vector3, room: RoomSpec, def: DungeonTypeDef, wall_h: float = DD.WALL_HEIGHT) -> void:
	var key := OmniLight3D.new()
	key.name = "RoomFill"
	key.position = origin + Vector3(0, wall_h * 0.72, 0)
	var cool := Color(0.52, 0.64, 0.80)
	if def != null and String(def.id) == "cavern":
		cool = Color(0.48, 0.60, 0.56)
	key.light_color = cool
	key.light_energy = 4.0 if room.kind == DD.RoomKind.BOSS else 3.1
	key.omni_range = 12.0
	key.omni_attenuation = 0.95
	VisualLook.configure_omni(key, false)
	parent.add_child(key)
	var vault := OmniLight3D.new()
	vault.name = "VaultFill"
	vault.position = origin + Vector3(0, wall_h + DungeonKit.vault_rise(wall_h) * 0.45, 0)
	vault.light_color = Color(1.0, 0.84, 0.58) if def == null or String(def.id) != "cavern" else Color(0.78, 0.82, 0.70)
	vault.light_energy = 2.2 if room.kind == DD.RoomKind.BOSS else 1.55
	vault.omni_range = 8.5
	vault.omni_attenuation = 1.15
	vault.shadow_enabled = false
	VisualLook.configure_omni(vault, false)
	parent.add_child(vault)
