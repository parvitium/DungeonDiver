extends Node
## Windowed screenshot helper. Autoloads are bound.
##   godot --path . res://scenes/capture_preview.tscn -- --out=/tmp/dd_preview --tag=before


var _out_dir: String = "/tmp/dd_preview"
var _tag: String = "shot"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	await _settle(6)
	await _capture_title_or_hub()
	await _capture_dungeon(&"crypt", "crypt")
	await _capture_dungeon(&"cavern", "cavern")
	await _capture_creature_sheet(&"crypt")
	print("CAPTURE_OK %s" % _out_dir)
	get_tree().quit(0)


func _capture_title_or_hub() -> void:
	var path := "res://scenes/title.tscn"
	if not ResourceLoader.exists(path):
		path = "res://scenes/hub.tscn"
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await _settle(12)
	_save(scene.name.to_lower())
	var settings := scene.find_child("Settings", true, false)
	if settings is SettingsPanel:
		settings.visible = true
		await _settle(6)
		_save("settings")
		settings.visible = false
	scene.queue_free()
	await _settle(2)


func _capture_dungeon(dungeon_id: StringName, label: String) -> void:
	GameSession.start_run(dungeon_id, 1, 2026)
	var run: Node = load("res://scenes/dungeon_run.tscn").instantiate()
	add_child(run)
	await _settle(14)
	_save(label)
	if label == "crypt":
		_save("crypt_spawn")
	var player := get_tree().get_first_node_in_group("player")
	if player is Player:
		player.rotate_y(0.28)
		player.look_pitch = 0.18
		if player._camera:
			player._camera.get_parent().rotation.x = player.look_pitch
		player.global_position += -player.global_transform.basis.z * 1.15
		await _settle(6)
		_save(label + "_look")
		var mobs := get_tree().get_nodes_in_group("monsters")
		var mob: Node3D = _pick_showcase_monster(mobs)
		if mob:
			GameSession.accept_local_input = false
			player.input_enabled = false
			player.set_physics_process(false)
			mob.set_physics_process(false)
			var stand: Vector3 = player.global_position
			var dir: Vector3 = _open_offset(player).normalized()
			player.global_position = stand + dir * 1.45
			mob.global_position = stand + dir * 3.55
			if mob.has_method("sync_home"):
				mob.call("sync_home")
			_aim_player_at(player, mob)
			_face_toward(mob, player.global_position)
			var lamp := OmniLight3D.new()
			lamp.name = "CaptureFill"
			lamp.light_color = Color(1.0, 0.90, 0.74)
			lamp.light_energy = 6.2
			lamp.omni_range = 8.0
			lamp.omni_attenuation = 0.9
			lamp.shadow_enabled = false
			lamp.position = Vector3(0.2, 1.6, 0.8)
			mob.add_child(lamp)
			if mob.has_method("receive_hit"):
				mob.call("receive_hit", 4.0, player.global_position, true)
			await _settle(8)
			_aim_player_at(player, mob)
			await _settle(3)
			_save(label + "_monster")
			if label == "crypt":
				await _capture_hud_overlays(run, player)
			GameSession.accept_local_input = true
	run.queue_free()
	if GameSession.run != null:
		GameSession.end_run(false)
	await _settle(2)


func _capture_creature_sheet(dungeon_id: StringName) -> void:
	GameSession.start_run(dungeon_id, 1, 2026)
	var run: Node = load("res://scenes/dungeon_run.tscn").instantiate()
	add_child(run)
	await _settle(12)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		run.queue_free()
		return
	GameSession.accept_local_input = false
	if player is Player:
		player.input_enabled = false
		player.set_physics_process(false)
	for existing in get_tree().get_nodes_in_group("monsters"):
		existing.set_physics_process(false)
		existing.visible = false
	var stand: Vector3 = player.global_position
	var dir: Vector3 = _open_offset(player).normalized()
	if dir.length() < 0.05:
		dir = Vector3(0, 0, -1)
	var ids: PackedStringArray = ["skeleton", "wraith", "lich", "cave_troll", "cave_wolf"]
	for id in ids:
		var def: MonsterDef = ContentDB.get_monster(StringName(id))
		if def == null:
			continue
		var monster_script: GDScript = load("res://src/monster/monster.gd")
		var mob: Node = monster_script.new()
		run.add_child(mob)
		mob.call("setup", def, 1)
		mob.set_physics_process(false)
		var gameplay := stand + dir * 3.35
		mob.global_position = gameplay
		if mob.has_method("sync_home"):
			mob.call("sync_home")
		player.global_position = stand + dir * 0.15
		_face_toward(mob, player.global_position)
		_aim_player_at(player, mob)
		var lamp := OmniLight3D.new()
		lamp.name = "CaptureFill"
		lamp.light_color = Color(1.0, 0.91, 0.74)
		lamp.light_energy = 11.0
		lamp.omni_range = 10.0
		lamp.omni_attenuation = 0.85
		lamp.shadow_enabled = false
		lamp.position = Vector3(0.15, 1.55, 0.85)
		mob.add_child(lamp)
		if mob.has_method("receive_hit"):
			mob.call("receive_hit", 3.0, player.global_position, true)
		await _settle(8)
		_aim_player_at(player, mob)
		await _settle(3)
		_save("%s_gameplay" % id)
		var side := Vector3(dir.z, 0, -dir.x)
		if side.length() < 0.05:
			side = Vector3(1, 0, 0)
		side = side.normalized()
		var side_amt := 0.85 if id == "cave_wolf" else 0.48
		player.global_position = gameplay - dir * (0.95 if id == "cave_wolf" else 0.78) + side * side_amt
		_face_toward(mob, player.global_position)
		_aim_player_at(player, mob)
		if player is Player:
			(player as Player).look_pitch = -0.12 if id == "cave_wolf" else 0.06
			if player._camera:
				player._camera.get_parent().rotation.x = (player as Player).look_pitch
		await _settle(5)
		_save("%s_close" % id)
		mob.queue_free()
		await _settle(2)
	GameSession.accept_local_input = true
	run.queue_free()
	if GameSession.run != null:
		GameSession.end_run(false)
	await _settle(2)


func _capture_hud_overlays(run: Node, player: Node) -> void:
	var hud: Node = null
	for child in run.get_children():
		if child is CanvasLayer and child.has_method("bind_player"):
			hud = child
			break
	if hud == null:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hud.get("_pause_panel"):
		hud._close_all()
		hud._pause_panel.visible = true
		hud._pause_panel.refresh()
		GameSession.ui_open = true
		await _settle(6)
		_save("pause")
		hud._pause_panel.visible = false
	if hud.get("_bestiary_panel"):
		hud._bestiary_panel.visible = true
		hud._bestiary_panel.refresh()
		GameSession.ui_open = true
		await _settle(6)
		_save("bestiary")
		hud._bestiary_panel.visible = false
	hud._close_all()
	if player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _save(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [_out_dir, _tag, name]
	var err := img.save_png(path)
	print("WROTE %s err=%s %dx%d" % [path, str(err), img.get_width(), img.get_height()])


func _pick_showcase_monster(mobs: Array) -> Node3D:
	for node in mobs:
		if node is Node3D and node.get("def") and String(node.def.id) == "skeleton":
			return node
	for node in mobs:
		if node is Node3D:
			return node
	return null


func _open_offset(player: Node3D) -> Vector3:
	var origin := player.global_position + Vector3(0, 1.2, 0)
	var dirs: Array[Vector3] = [
		-player.global_transform.basis.z,
		Vector3(0, 0, -1),
		Vector3(0, 0, 1),
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0.7, 0, -0.7),
		Vector3(-0.7, 0, -0.7),
	]
	var space := player.get_world_3d().direct_space_state
	var best := Vector3(0, 0, -2.5)
	var best_dist := 0.0
	for raw in dirs:
		var dir := raw
		dir.y = 0
		if dir.length() < 0.05:
			continue
		dir = dir.normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 8.0)
		query.collision_mask = DD.WORLD_LAYER
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		var dist := 8.0 if hit.is_empty() else origin.distance_to(hit.position)
		if dist > best_dist:
			best_dist = dist
			best = dir * clampf(dist * 0.42, 2.1, 2.8)
	return best


func _face_toward(node: Node3D, point: Vector3) -> void:
	var look := point
	look.y = node.global_position.y
	if look.distance_to(node.global_position) > 0.05:
		node.look_at(look, Vector3.UP)


func _aim_player_at(player: Node3D, mob: Node3D) -> void:
	var desired := mob.global_position - player.global_position
	desired.y = 0
	if desired.length() < 0.05:
		return
	var current := -player.global_transform.basis.z
	current.y = 0
	if current.length() < 0.05:
		current = Vector3(0, 0, -1)
	player.rotate_y(current.signed_angle_to(desired, Vector3.UP))
	if player is Player:
		(player as Player).look_pitch = -0.06
		if player._camera:
			player._camera.get_parent().rotation.x = (player as Player).look_pitch


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		await get_tree().physics_frame
