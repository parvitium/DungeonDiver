extends Node
## Lobby screenshot. Not part of CI.
##   godot --path . res://tools/capture_hub.tscn -- --tag=after

const OUT_DIR := "res://docs/screenshots"


func _ready() -> void:
	var tag := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_viewport().msaa_2d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await _settle()
	_save(tag + "_hub_lobby")
	print("CAPTURE_HUB OK tag=%s" % tag)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0)


func _settle() -> void:
	for _i in 10:
		await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw


func _save(stem: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, stem]
	var err := img.save_png(path)
	print("saved %s err=%s" % [path, str(err)])
