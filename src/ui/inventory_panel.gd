extends Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func refresh() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := ThemeFactory.centered_sheet(self, Vector2(840, 560))

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 12
	root.offset_right = -16
	root.offset_bottom = -12
	panel.add_child(root)
	root.add_child(ThemeFactory.label("Pack & Harness", 26, Color(0.95, 0.82, 0.45)))
	var stats := GameSession.profile.total_stats()
	root.add_child(ThemeFactory.label("Worn totals  %s" % stats.summarize(), 15, Color(0.8, 0.75, 0.6)))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var wear := VBoxContainer.new()
	wear.custom_minimum_size = Vector2(300, 0)
	wear.add_child(ThemeFactory.label("Equipped", 18))
	for slot in Inventory.SLOT_COUNT:
		var item: Variant = GameSession.profile.inventory.equipped[slot]
		var row := HBoxContainer.new()
		row.add_child(ThemeFactory.label(DD.slot_name(slot), 14, Color(0.7, 0.65, 0.5)))
		if item != null:
			var btn := Button.new()
			btn.text = item.full_name()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ThemeFactory.apply_button(btn)
			btn.add_theme_color_override("font_color", DD.rarity_color(item.rarity))
			btn.pressed.connect(_unequip.bind(slot))
			row.add_child(btn)
		else:
			row.add_child(ThemeFactory.label("— empty —", 14, Color(0.45, 0.42, 0.38)))
		wear.add_child(row)
	cols.add_child(wear)

	var bag := VBoxContainer.new()
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag.add_child(ThemeFactory.label("Bag", 18))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	bag.add_child(scroll)
	if GameSession.profile.inventory.items.is_empty():
		list.add_child(ThemeFactory.label("Nothing stowed. Kill, smash chests, repeat.", 14, Color(0.55, 0.5, 0.42)))
	for item in GameSession.profile.inventory.items:
		var btn := Button.new()
		btn.text = "%s  [%s]  %s" % [item.full_name(), DD.slot_name(item.slot), item.stats.summarize()]
		ThemeFactory.apply_button(btn)
		btn.add_theme_color_override("font_color", DD.rarity_color(item.rarity))
		btn.pressed.connect(_equip.bind(item.instance_id))
		list.add_child(btn)
	cols.add_child(bag)


func _equip(instance_id: String) -> void:
	GameSession.profile.inventory.equip(instance_id)
	GameSession.profile.clamp_vitals()
	GameSession.profile_changed.emit()
	refresh()


func _unequip(slot: int) -> void:
	GameSession.profile.inventory.unequip(slot)
	GameSession.profile.clamp_vitals()
	GameSession.profile_changed.emit()
	refresh()
