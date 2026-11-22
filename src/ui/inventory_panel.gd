extends Control
## Anchored Pack & Harness used by the lobby and the in-dungeon Tab/I menu.

const SLOT_ORDER: Array[int] = [
	DD.EquipSlot.HEAD,
	DD.EquipSlot.CHEST,
	DD.EquipSlot.LEGS,
	DD.EquipSlot.WEAPON,
	DD.EquipSlot.OFFHAND,
	DD.EquipSlot.ACCESSORY,
	DD.EquipSlot.RING,
]

const FILTERS: Array[Dictionary] = [
	{"id": -1, "label": "All"},
	{"id": DD.EquipSlot.WEAPON, "label": "Weapon"},
	{"id": DD.EquipSlot.OFFHAND, "label": "Offhand"},
	{"id": DD.EquipSlot.HEAD, "label": "Head"},
	{"id": DD.EquipSlot.CHEST, "label": "Chest"},
	{"id": DD.EquipSlot.LEGS, "label": "Legs"},
	{"id": DD.EquipSlot.ACCESSORY, "label": "Accessory"},
	{"id": DD.EquipSlot.CONSUMABLE, "label": "Potions"},
]

var heading: String = "Pack & Harness"
var show_name_editor: bool = false
var _filter_id: int = -1
var _sort_mode: String = "rarity"
var _selected_id: String = ""
var _bag_scroll: ScrollContainer
var _bag_list: VBoxContainer
var _detail: VBoxContainer
var _flash: ColorRect
var _confirm: Panel
var _status: Label
var _list_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	resized.connect(_fit_modal)
	refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_nudge_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_nudge_selection(-1)
		get_viewport().set_input_as_handled()


func close() -> void:
	visible = false
	if _confirm:
		_confirm.queue_free()
		_confirm = null


func _fit_modal() -> void:
	var panel := find_child("PackPanel", true, false) as Control
	if panel:
		ThemeFactory.fit_modal_panel(self, panel)


func refresh() -> void:
	var keep_filter := _filter_id
	var keep_sort := _sort_mode
	var keep_sel := _selected_id
	while get_child_count() > 0:
		get_child(0).free()
	_filter_id = keep_filter
	_sort_mode = keep_sort
	_selected_id = keep_sel
	_list_buttons.clear()
	_build()


func _build() -> void:
	var panel := ThemeFactory.mount_modal(self, true)
	_fit_modal()

	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(inner)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	inner.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := ThemeFactory.label(heading, 26, Color(0.95, 0.82, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if show_name_editor:
		var name_edit := LineEdit.new()
		name_edit.text = GameSession.profile.display_name
		name_edit.placeholder_text = "Character name"
		name_edit.custom_minimum_size = Vector2(220, 32)
		name_edit.max_length = 24
		name_edit.text_changed.connect(func(v: String) -> void:
			var trimmed := v.strip_edges()
			GameSession.profile.display_name = trimmed if not trimmed.is_empty() else "Diver"
		)
		header.add_child(name_edit)
	_status = ThemeFactory.label("I / Tab / Esc closes", 14, Color(0.7, 0.65, 0.5))
	header.add_child(_status)
	header.add_child(ThemeFactory.close_button(close))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	root.add_child(cols)
	cols.add_child(_build_left())
	cols.add_child(_build_right())

	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.72, 0.3, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_flash)

	_rebuild_list()
	_refresh_detail()


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.42
	left.add_theme_constant_override("separation", 8)
	left.add_child(ThemeFactory.label("Character", 18, Color(0.95, 0.82, 0.45)))
	var totals := GameSession.profile.total_stats()
	var stats_box := Panel.new()
	stats_box.add_theme_stylebox_override("panel", _inset())
	left.add_child(stats_box)
	var stats_lbl := ThemeFactory.label(_totals_text(totals), 15, Color(0.86, 0.8, 0.62))
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_box.add_child(stats_lbl)
	stats_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_lbl.offset_left = 10
	stats_lbl.offset_top = 8
	stats_lbl.offset_right = -10
	stats_lbl.offset_bottom = -8
	stats_box.custom_minimum_size = Vector2(0, 88)

	left.add_child(ThemeFactory.label("Equipped", 18, Color(0.95, 0.82, 0.45)))
	var slot_scroll := ScrollContainer.new()
	slot_scroll.name = "SlotScroll"
	slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(slot_scroll)
	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 6)
	slot_scroll.add_child(slots)
	for slot in SLOT_ORDER:
		slots.add_child(_equip_card(slot))
	return left


func _build_right() -> Control:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.58
	right.add_theme_constant_override("separation", 8)
	right.add_child(ThemeFactory.label("Inventory", 18, Color(0.95, 0.82, 0.45)))

	var filter_scroll := ScrollContainer.new()
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.custom_minimum_size = Vector2(0, 40)
	right.add_child(filter_scroll)
	var filters := HBoxContainer.new()
	filters.name = "FilterRow"
	filters.add_theme_constant_override("separation", 6)
	filter_scroll.add_child(filters)
	for spec in FILTERS:
		var btn := Button.new()
		btn.text = str(spec["label"])
		ThemeFactory.apply_button(btn)
		if int(spec["id"]) == _filter_id:
			btn.modulate = Color(1.2, 1.1, 0.75)
		btn.pressed.connect(_set_filter.bind(int(spec["id"])))
		filters.add_child(btn)

	var sorts := HBoxContainer.new()
	sorts.add_theme_constant_override("separation", 6)
	right.add_child(sorts)
	sorts.add_child(ThemeFactory.label("Sort", 14, Color(0.7, 0.65, 0.5)))
	for mode in ["rarity", "attack", "defense", "health"]:
		var sbtn := Button.new()
		sbtn.text = mode.capitalize()
		ThemeFactory.apply_button(sbtn)
		if mode == _sort_mode:
			sbtn.modulate = Color(1.2, 1.1, 0.75)
		sbtn.pressed.connect(_set_sort.bind(mode))
		sorts.add_child(sbtn)

	_bag_scroll = ScrollContainer.new()
	_bag_scroll.name = "BagScroll"
	_bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_scroll.follow_focus = true
	right.add_child(_bag_scroll)
	_bag_list = VBoxContainer.new()
	_bag_list.name = "BagList"
	_bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_list.add_theme_constant_override("separation", 6)
	_bag_scroll.add_child(_bag_list)

	_detail = VBoxContainer.new()
	_detail.name = "DetailCard"
	_detail.custom_minimum_size = Vector2(0, 150)
	_detail.add_theme_constant_override("separation", 6)
	right.add_child(_detail)
	return right


func _equip_card(slot: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 64)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _inset())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var slot_lbl := ThemeFactory.label(DD.slot_name(slot), 13, Color(0.72, 0.66, 0.5))
	slot_lbl.custom_minimum_size = Vector2(78, 0)
	row.add_child(slot_lbl)
	var item: Variant = GameSession.profile.inventory.equipped[slot]
	if item != null:
		row.add_child(_icon(item))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var name := ThemeFactory.label(item.full_name(), 14, DD.rarity_color(item.rarity))
		name.clip_text = false
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(name)
		col.add_child(ThemeFactory.label(item.stats.summarize(), 12, Color(0.75, 0.7, 0.55)))
		var un := Button.new()
		un.text = "Unequip"
		ThemeFactory.apply_button(un)
		un.pressed.connect(_do_unequip.bind(slot))
		row.add_child(un)
	else:
		var empty := ThemeFactory.label("— empty —", 14, Color(0.45, 0.42, 0.38))
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(empty)
	return card


func _rebuild_list() -> void:
	if _bag_list == null:
		return
	for child in _bag_list.get_children():
		child.queue_free()
	_list_buttons.clear()
	var entries := _filtered_entries()
	if entries.is_empty():
		_bag_list.add_child(ThemeFactory.label("Nothing in this filter. Loot chests and fallen foes.", 14, Color(0.55, 0.5, 0.42), true))
		return
	if _selected_id.is_empty() or GameSession.profile.inventory.find(_selected_id) == null:
		_selected_id = entries[0].item.instance_id
	for entry in entries:
		_bag_list.add_child(_bag_row(entry.item, entry.equipped))


func _filtered_entries() -> Array[Dictionary]:
	var inv: Inventory = GameSession.profile.inventory
	var raw: Array[Dictionary] = []
	for slot in inv.equipped.size():
		var worn: Variant = inv.equipped[slot]
		if worn != null:
			raw.append({"item": worn, "equipped": true, "slot": slot})
	for item in inv.items:
		raw.append({"item": item, "equipped": false, "slot": int(item.slot)})
	var out: Array[Dictionary] = []
	for entry in raw:
		var item: ItemInstance = entry["item"]
		if _filter_id >= 0:
			if _filter_id == int(DD.EquipSlot.ACCESSORY):
				if int(item.slot) != int(DD.EquipSlot.ACCESSORY) and int(item.slot) != int(DD.EquipSlot.RING):
					continue
			elif int(item.slot) != _filter_id:
				continue
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ia: ItemInstance = a["item"]
		var ib: ItemInstance = b["item"]
		match _sort_mode:
			"attack":
				return ia.stats.attack > ib.stats.attack
			"defense":
				return ia.stats.defense > ib.stats.defense
			"health":
				return ia.stats.max_health > ib.stats.max_health
			_:
				if ia.rarity == ib.rarity:
					return ia.full_name() < ib.full_name()
				return int(ia.rarity) > int(ib.rarity)
	)
	return out


func _bag_row(item: ItemInstance, equipped: bool) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 58)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _inset()
	if item.instance_id == _selected_id:
		style.border_color = Color(0.95, 0.82, 0.45)
		style.set_border_width_all(2)
	if equipped:
		style.bg_color = Color(0.18, 0.15, 0.08, 0.95)
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(_icon(item))
	if equipped:
		var badge := ThemeFactory.label("E", 16, Color(0.12, 0.1, 0.06))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(22, 22)
		var badge_bg := ColorRect.new()
		badge_bg.color = Color(0.95, 0.82, 0.42)
		badge_bg.custom_minimum_size = Vector2(22, 22)
		badge_bg.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(badge_bg)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name := ThemeFactory.label(item.full_name(), 15, DD.rarity_color(item.rarity))
	name.clip_text = false
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(name)
	var sub := item.stats.summarize() if not item.is_consumable else "Potion  +%d HP" % int(item.heal_amount)
	col.add_child(ThemeFactory.label("%s · %s" % [DD.slot_name(item.slot), sub], 12, Color(0.7, 0.65, 0.52)))
	var pick := Button.new()
	pick.text = "Select"
	ThemeFactory.apply_button(pick)
	pick.focus_mode = Control.FOCUS_ALL
	pick.pressed.connect(_select.bind(item.instance_id))
	pick.mouse_entered.connect(_select.bind(item.instance_id))
	row.add_child(pick)
	_list_buttons.append(pick)
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_select(item.instance_id)
	)
	return card


func _refresh_detail() -> void:
	if _detail == null:
		return
	for child in _detail.get_children():
		child.queue_free()
	var item := GameSession.profile.inventory.find(_selected_id)
	if item == null:
		_detail.add_child(ThemeFactory.label("Select an item to inspect stats.", 14, Color(0.65, 0.6, 0.5)))
		return
	var equipped := GameSession.profile.inventory.is_equipped(item.instance_id)
	var head := ThemeFactory.label(item.full_name(), 18, DD.rarity_color(item.rarity))
	head.clip_text = false
	_detail.add_child(head)
	_detail.add_child(ThemeFactory.label("%s · %s" % [DD.rarity_name(item.rarity), DD.slot_name(item.slot)], 13, Color(0.75, 0.7, 0.55)))
	if item.is_consumable:
		_detail.add_child(ThemeFactory.label("Restores %d health." % int(item.heal_amount), 14, Color(0.7, 0.85, 0.55)))
	else:
		_detail.add_child(_compare_block(item))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_detail.add_child(actions)
	if item.is_consumable:
		actions.add_child(_action_btn("Use", func() -> void: _do_use(item.instance_id)))
	elif equipped:
		actions.add_child(_action_btn("Unequip", func() -> void: _do_unequip(GameSession.profile.inventory.equipped_slot_of(item.instance_id))))
	else:
		actions.add_child(_action_btn("Equip", func() -> void: _do_equip(item.instance_id)))
	actions.add_child(_action_btn("Discard", func() -> void: _ask_discard(item.instance_id)))


func _compare_block(item: ItemInstance) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var dest := GameSession.profile.inventory.preferred_slot(item)
	var worn: Variant = GameSession.profile.inventory.equipped[dest] if dest >= 0 else null
	if worn != null and worn.instance_id != item.instance_id:
		box.add_child(ThemeFactory.label("Compared to %s" % worn.full_name(), 12, Color(0.65, 0.6, 0.48)))
	else:
		box.add_child(ThemeFactory.label("No item in this slot yet.", 12, Color(0.65, 0.6, 0.48)))
	var old_stats: StatBlock = worn.stats if worn != null and worn.instance_id != item.instance_id else StatBlock.new()
	for pair in [
		["ATK", item.stats.attack, old_stats.attack],
		["DEF", item.stats.defense, old_stats.defense],
		["HP", item.stats.max_health, old_stats.max_health],
		["STA", item.stats.max_stamina, old_stats.max_stamina],
		["SP", item.stats.spell_power, old_stats.spell_power],
	]:
		box.add_child(_stat_delta_line(str(pair[0]), float(pair[1]), float(pair[2])))
	return box


func _stat_delta_line(label: String, next_v: float, prev_v: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(ThemeFactory.label("%s  %+0.1f" % [label, next_v], 14, Color(0.9, 0.85, 0.7)))
	var delta := next_v - prev_v
	var color := Color(0.55, 0.55, 0.5)
	var arrow := "•"
	if delta > 0.05:
		color = Color(0.45, 0.85, 0.45)
		arrow = "▲"
	elif delta < -0.05:
		color = Color(0.9, 0.35, 0.32)
		arrow = "▼"
	row.add_child(ThemeFactory.label("%s %+0.1f vs %+0.1f" % [arrow, next_v, prev_v], 14, color))
	return row


func _action_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	return btn


func _icon(item: ItemInstance) -> ColorRect:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.color = DD.rarity_color(item.rarity).darkened(0.5)
	var letter := ThemeFactory.label(item.display_name.substr(0, 1), 18, DD.rarity_color(item.rarity))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(letter)
	return icon


func _inset() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.1, 0.08, 0.92)
	box.border_color = Color(0.72, 0.58, 0.28, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _totals_text(stats: StatBlock) -> String:
	return "ATK %0.1f    DEF %0.1f    HP %0.0f    STA %0.0f    SP %0.1f" % [
		stats.attack, stats.defense, stats.max_health, stats.max_stamina, stats.spell_power
	]


func _set_filter(slot: int) -> void:
	_filter_id = slot
	refresh()


func _set_sort(mode: String) -> void:
	_sort_mode = mode
	refresh()


func _select(instance_id: String) -> void:
	_selected_id = instance_id
	_rebuild_list()
	_refresh_detail()


func _nudge_selection(dir: int) -> void:
	var entries := _filtered_entries()
	if entries.is_empty():
		return
	var idx := 0
	for i in entries.size():
		if entries[i].item.instance_id == _selected_id:
			idx = i
			break
	idx = clampi(idx + dir, 0, entries.size() - 1)
	_select(entries[idx].item.instance_id)
	if _bag_scroll and idx < _list_buttons.size():
		_list_buttons[idx].grab_focus()


func _do_equip(instance_id: String) -> void:
	if GameSession.profile.inventory.equip(instance_id):
		GameSession.profile.clamp_vitals()
		GameSession.profile_changed.emit()
		SaveService.save_active()
		_pulse("Equipped")
		refresh()


func _do_unequip(slot: int) -> void:
	if GameSession.profile.inventory.unequip(slot):
		GameSession.profile.clamp_vitals()
		GameSession.profile_changed.emit()
		SaveService.save_active()
		_pulse("Unequipped")
		refresh()


func _do_use(instance_id: String) -> void:
	if GameSession.use_item(instance_id):
		_pulse("Used")
		refresh()


func _ask_discard(instance_id: String) -> void:
	if _confirm:
		_confirm.queue_free()
	_confirm = Panel.new()
	_confirm.add_theme_stylebox_override("panel", ThemeFactory.panel())
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.position = Vector2(-170, -70)
	_confirm.size = Vector2(340, 140)
	add_child(_confirm)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 12
	box.offset_bottom = -12
	_confirm.add_child(box)
	box.add_child(ThemeFactory.label("Discard this item? It will be gone.", 15, Color(0.95, 0.82, 0.45)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_action_btn("Discard", func() -> void:
		GameSession.profile.inventory.discard(instance_id)
		GameSession.profile_changed.emit()
		SaveService.save_active()
		_confirm.queue_free()
		_confirm = null
		_pulse("Discarded")
		refresh()
	))
	row.add_child(_action_btn("Cancel", func() -> void:
		_confirm.queue_free()
		_confirm = null
	))


func _pulse(text: String) -> void:
	if _status:
		_status.text = text
	if _flash == null:
		return
	_flash.color = Color(0.85, 0.72, 0.3, 0.28)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.28)
