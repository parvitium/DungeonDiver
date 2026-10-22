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
	var player := get_tree().get_first_node_in_group("player")
	if player is Player:
		player.rotate_y(0.85)
		player.look_pitch = -0.12
		if player._camera:
			player._camera.get_parent().rotation.x = player.look_pitch
		await _settle(6)
		_save(label + "_look")
		var mobs := get_tree().get_nodes_in_group("monsters")
		if not mobs.is_empty() and mobs[0] is Node3D:
			var mob: Node3D = mobs[0]
			player.global_position = mob.global_position + Vector3(0.0, 0.05, 2.8)
			player.rotation_degrees = Vector3.ZERO
			player.look_at(mob.global_position + Vector3(0, 0.9, 0), Vector3.UP)
			player.look_pitch = -0.08
			if player._camera:
				player._camera.get_parent().rotation.x = player.look_pitch
			await _settle(8)
			_save(label + "_monster")
	run.queue_free()
	if GameSession.run != null:
		GameSession.end_run(false)
	await _settle(2)


func _save(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [_out_dir, _tag, name]
	var err := img.save_png(path)
	print("WROTE %s err=%s %dx%d" % [path, str(err), img.get_width(), img.get_height()])


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		await get_tree().physics_frame
