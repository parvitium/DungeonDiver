extends Node
## Capture every main-menu and town screen for the PR.
##   godot --path . res://tools/capture_screens.tscn

const OUT_DIR := "res://docs/screenshots"


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_viewport().msaa_2d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _run()
	get_tree().quit(0)


func _run() -> void:
	var saves := SaveService
	saves.clear_slot(1)
	saves.new_game_in_slot(1, "Mara")
	GameSession.profile.gold = 180
	GameSession.profile.progression.record_kill(&"skeleton")
	GameSession.profile.progression.record_clear(&"crypt", 2)
	Shop.ensure_stock(GameSession.profile, ContentDB.items, 11)
	saves.save_slot(1)

	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _settle()
	_save("menu_home")
	menu.open_new_game()
	await _settle()
	_save("menu_new_game_slots")
	menu._choose_new_slot(1, true)
	await _settle()
	_save("menu_new_game_name")
	menu.open_load()
	await _settle()
	_save("menu_load_game")
	menu.open_multiplayer()
	await _settle()
	_save("menu_multiplayer")
	menu.open_settings()
	await _settle()
	_save("menu_settings")
	menu.free()

	saves.load_slot(1)
	var hub: Node = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await _settle()
	_save("town_hub")
	hub.open_character()
	await _settle()
	_save("town_character")
	hub.open_pack()
	await _settle()
	_save("town_pack")
	hub.open_bestiary_view()
	await _settle()
	_save("town_bestiary")
	hub.open_dungeon_select()
	await _settle()
	_save("town_dungeon_select")
	hub.open_shop()
	await _settle()
	_save("town_shop")
	hub.open_pause()
	await _settle()
	_save("town_pause")
	hub.open_settings()
	await _settle()
	_save("town_settings")
	hub.free()
	print("CAPTURE_SCREENS OK")


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
