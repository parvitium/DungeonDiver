extends Node3D
## Renders the dungeon + monster lineup to PNG. Not part of CI.
##   godot --path . res://tools/capture_preview.tscn -- --tag=before

const OUT_DIR := "res://docs/screenshots"


func _ready() -> void:
	var tag := "shot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_viewport().msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	GameSession.start_run(&"crypt", 1, 42)
	var def: DungeonTypeDef = ContentDB.get_dungeon(&"crypt")
	var markers: Dictionary = DungeonBuilder.new().build(self, GameSession.run.blueprint, def, false)

	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.08
	cam.far = 80.0
	add_child(cam)
	cam.current = true

	var start: Vector3 = markers["player"]
	# Looking from the start room toward the first doorway / hall.
	cam.global_position = start + Vector3(0.4, 1.55, 2.2)
	cam.look_at(start + Vector3(0.2, 1.1, 8.5), Vector3.UP)
	await _settle()
	_save(tag + "_crypt_room")

	cam.global_position = start + Vector3(2.8, 1.4, 2.6)
	cam.look_at(start + Vector3(5.2, 1.1, 5.2), Vector3.UP)
	await _settle()
	_save(tag + "_crypt_corner")

	# Monster lineup in the start room, in front of the camera.
	var lineup := [
		&"skeleton", &"cave_wolf", &"wraith", &"lich", &"cave_troll",
	]
	var mobs: Array[Monster] = []
	for i in lineup.size():
		var mdef: MonsterDef = ContentDB.get_monster(lineup[i])
		var mob := Monster.new()
		add_child(mob)
		mob.setup(mdef, 1)
		mob.set_physics_process(false)
		mob.global_position = start + Vector3(-4.0 + float(i) * 2.0, 0.05, 4.6)
		mob.look_at(start + Vector3(-4.0 + float(i) * 2.0, 0.05, 0.0), Vector3.UP)
		mobs.append(mob)
	cam.global_position = start + Vector3(0.0, 1.85, 0.15)
	cam.look_at(start + Vector3(0.0, 0.95, 4.6), Vector3.UP)
	await _settle()
	_save(tag + "_mobs")

	if not mobs.is_empty():
		cam.global_position = mobs[0].global_position + Vector3(0.9, 1.35, 1.8)
		cam.look_at(mobs[0].global_position + Vector3(0, 0.9, 0), Vector3.UP)
		await _settle()
		_save(tag + "_skeleton_close")

	GameSession.start_run(&"cavern", 1, 42)
	var cavern: DungeonTypeDef = ContentDB.get_dungeon(&"cavern")
	for child in get_children():
		if child != cam:
			child.queue_free()
	await get_tree().process_frame
	var cavern_markers: Dictionary = DungeonBuilder.new().build(self, GameSession.run.blueprint, cavern, false)
	var cstart: Vector3 = cavern_markers["player"]
	cam.global_position = cstart + Vector3(0.4, 1.55, 2.2)
	cam.look_at(cstart + Vector3(0.2, 1.1, 8.5), Vector3.UP)
	await _settle()
	_save(tag + "_cavern_room")

	print("CAPTURE_PREVIEW OK tag=%s" % tag)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0)


func _settle() -> void:
	for _i in 8:
		await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw


func _save(stem: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, stem]
	var err := img.save_png(path)
	print("saved %s err=%s" % [path, str(err)])
