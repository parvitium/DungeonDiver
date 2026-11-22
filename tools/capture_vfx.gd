extends Node3D
## Captures combat VFX stills. Not part of CI.
##   godot --path . res://tools/capture_vfx.tscn -- --tag=after

const OUT_DIR := "res://docs/screenshots"


func _ready() -> void:
	var tag := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_viewport().msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.04, 0.035)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.28, 0.22)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var floor := Greybox.make_box_with_material(Vector3(14, 0.3, 14), DungeonMaterials.floor_mat(Catalog.all_dungeons()[0]))
	floor.position = Vector3(0, -0.15, 0)
	add_child(floor)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.8, 0.55)
	fill.light_energy = 1.4
	fill.omni_range = 12.0
	fill.position = Vector3(0, 3.2, 2)
	add_child(fill)

	var vfx := CombatVfx.new()
	add_child(vfx)
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0.4, 1.5, 3.2)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)

	await _shot(tag, "vfx_fireball", func() -> void:
		var p := Projectile.new()
		p.setup(Vector3(-0.4, 1.1, 1.6), Vector3(0.2, 0.05, -1), 8.0, 0.01, true, Color(1.0, 0.45, 0.1), &"fireball")
		add_child(p)
		vfx.cast_flash(Vector3(-0.6, 1.2, 1.8), &"fireball")
	)
	await _shot(tag, "vfx_ice", func() -> void:
		var p := Projectile.new()
		p.setup(Vector3(-0.2, 1.15, 1.5), Vector3(0.1, 0, -1), 8.0, 0.01, false, Color(0.65, 0.85, 1.0), &"ice")
		add_child(p)
		vfx.cast_flash(Vector3(-0.4, 1.2, 1.7), &"ice")
	)
	await _shot(tag, "vfx_bolt", func() -> void:
		var p := Projectile.new()
		p.setup(Vector3(0.1, 1.15, 1.5), Vector3(0, 0, -1), 8.0, 0.01, false, Color(0.5, 0.8, 1.0), &"bolt")
		add_child(p)
		vfx.cast_flash(Vector3(0, 1.25, 1.7), &"bolt")
	)
	await _shot(tag, "vfx_arrow", func() -> void:
		var p := Projectile.new()
		p.setup(Vector3(0.0, 1.15, 1.4), Vector3(0, 0, -1), 8.0, 0.01, true, Color(0.75, 0.65, 0.4), &"arrow")
		add_child(p)
	)
	await _shot(tag, "vfx_hit_sparks", func() -> void:
		vfx.hit(Vector3(0, 1.0, 0.2), Vector3(0.4, 0.6, 0.2), &"metal")
		vfx.sword_impact(Vector3(0.15, 1.0, 0.3), Vector3(0, 0, -1))
	)
	await _shot(tag, "vfx_hit_bone", func() -> void:
		vfx.hit(Vector3(0, 1.0, 0.2), Vector3(0.2, 0.8, 0.1), &"bone")
	)
	await _shot(tag, "vfx_hit_blood", func() -> void:
		vfx.hit(Vector3(0, 0.9, 0.2), Vector3(0.3, 0.5, 0.2), &"flesh")
	)
	await _shot(tag, "vfx_hit_dust", func() -> void:
		vfx.hit(Vector3(0, 0.7, 0.2), Vector3(0.2, 0.9, 0.1), &"stone")
	)
	await _shot(tag, "vfx_death_magic", func() -> void:
		vfx.death(Vector3(0, 1.0, 0.1), &"magic", self)
	)
	await _shot(tag, "vfx_death_bones", func() -> void:
		vfx.death(Vector3(0, 0.05, 0.2), &"bone", self)
	)

	print("CAPTURE_VFX OK tag=%s" % tag)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0)


func _shot(tag: String, stem: String, spawn: Callable) -> void:
	spawn.call()
	await _settle()
	_save("%s_%s" % [tag, stem])


func _settle() -> void:
	for _i in 6:
		await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw


func _save(stem: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, stem]
	var err := img.save_png(path)
	print("saved %s err=%s" % [path, str(err)])
