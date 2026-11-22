extends Node
## Screenshots of the redesigned pack UI. Not part of CI.
##   godot --path . res://tools/capture_inventory.tscn -- --tag=after

const OUT_DIR := "res://docs/screenshots"


func _ready() -> void:
	var tag := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_viewport().msaa_2d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	GameSession.reset_profile(false)
	_fill_long_pack()
	var panel: Control = preload("res://src/ui/inventory_panel.gd").new()
	add_child(panel)
	panel.visible = true
	panel.refresh()
	await _settle()
	_save(tag + "_pack_long")

	# Equip a few pieces so left slots and E badges are obvious.
	var inv: Inventory = GameSession.profile.inventory
	for id in ["fill_0", "fill_1", "fill_2", "fill_3"]:
		inv.equip(id)
	GameSession.profile_changed.emit()
	panel.refresh()
	await _settle()
	_save(tag + "_pack_equipped")

	print("CAPTURE_INVENTORY OK tag=%s" % tag)
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0)


func _fill_long_pack() -> void:
	var names := [
		"Ironbrand of the Deep Crypt",
		"Tattered Watch-Vest",
		"Wolfhide Greatcoat",
		"Ember Charm of Last Light",
		"Crypt-Worn Greaves",
		"Hide Buckler, Split Rim",
		"Leather Cap of the Scout",
		"Fang Dagger Named Howl",
		"Health Flask",
		"Ashen Circlet",
	]
	var slots := [
		DD.EquipSlot.WEAPON, DD.EquipSlot.CHEST, DD.EquipSlot.CHEST, DD.EquipSlot.ACCESSORY,
		DD.EquipSlot.LEGS, DD.EquipSlot.OFFHAND, DD.EquipSlot.HEAD, DD.EquipSlot.WEAPON,
		DD.EquipSlot.CONSUMABLE, DD.EquipSlot.HEAD,
	]
	for i in 24:
		var item := ItemInstance.new()
		item.instance_id = "fill_%d" % i
		item.def_id = &"rusty_sword"
		item.display_name = names[i % names.size()] + " %d" % (i + 1)
		item.slot = slots[i % slots.size()]
		item.rarity = (i % 5) as DD.Rarity
		item.stats = StatBlock.new(4.0 + float(i), 2.0 + float(i % 4), 8.0 + float(i), 3.0, float(i % 6))
		if item.slot == DD.EquipSlot.CONSUMABLE:
			item.is_consumable = true
			item.heal_amount = 40.0
		GameSession.profile.inventory.add_item(item)


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
