extends Control
## Full-viewport catalog of encountered monsters. Closable with B, Esc, or X.

const WEAKNESS := {
	"skeleton": "Blunt force · holy light",
	"cave_wolf": "Fire · exposed flanks",
	"wraith": "Solid steel · interrupting the cast",
	"lich": "Closing distance · breaking the ice shard",
	"cave_troll": "Fire · striking after a missed slam",
}


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
	if event.is_action_pressed("toggle_bestiary") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	visible = false


func _fit_modal() -> void:
	var panel := find_child("PackPanel", true, false) as Control
	if panel:
		ThemeFactory.fit_modal_panel(self, panel)


func refresh() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	var panel := ThemeFactory.mount_modal(self, true)
	_fit_modal()
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 18)
	inner.add_theme_constant_override("margin_top", 14)
	inner.add_theme_constant_override("margin_right", 18)
	inner.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(inner)
	var root := VBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	inner.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(ThemeFactory.label("Bestiary", 26, Color(0.95, 0.82, 0.45)))
	titles.add_child(ThemeFactory.label("Monsters you've encountered — portraits, stats, and kills.", 14, Color(0.78, 0.72, 0.58), true))
	header.add_child(ThemeFactory.close_button(close))

	var monsters := ContentDB.monster_ids()
	var found := GameSession.profile.progression.discovered_count(monsters)
	root.add_child(ThemeFactory.label("Catalogued  %d / %d" % [found, monsters.size()], 16, Color(0.85, 0.78, 0.5)))

	var scroll := ScrollContainer.new()
	scroll.name = "BestiaryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "BestiaryList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for monster_id in monsters:
		list.add_child(_entry(StringName(monster_id)))

	root.add_child(ThemeFactory.label("B / Esc closes", 13, Color(0.6, 0.55, 0.45)))


func _entry(monster_id: StringName) -> Panel:
	var def: MonsterDef = ContentDB.get_monster(monster_id)
	var kills := GameSession.profile.progression.kills_of(monster_id)
	var known := kills > 0
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.1, 0.08, 0.96)
	box.border_color = Color(0.72, 0.58, 0.28, 0.5) if known else Color(0.25, 0.22, 0.18, 0.8)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 8
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.color = def.color if known and def else Color(0.12, 0.11, 0.1)
	var mark := ThemeFactory.label("?" if not known else (def.display_name.substr(0, 1) if def else "?"), 28, Color(0.95, 0.9, 0.75) if known else Color(0.35, 0.32, 0.28))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(mark)
	row.add_child(portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	if known and def:
		col.add_child(ThemeFactory.label(def.display_name, 18, Color(0.95, 0.88, 0.7)))
		var kind := "Boss" if def.is_boss else "Beast"
		col.add_child(ThemeFactory.label("%s  ·  %d slain" % [kind, kills], 14, Color(0.8, 0.74, 0.58)))
		col.add_child(ThemeFactory.label("HP %0.0f   DMG %0.1f   Range %0.1f m" % [def.max_health, def.damage, def.attack_range], 13, Color(0.75, 0.7, 0.55)))
		var weak := str(WEAKNESS.get(String(monster_id), "Unknown"))
		col.add_child(ThemeFactory.label("Weakness  %s" % weak, 13, Color(0.85, 0.7, 0.45)))
	else:
		col.add_child(ThemeFactory.label("???", 18, Color(0.45, 0.42, 0.38)))
		col.add_child(ThemeFactory.label("Not yet encountered.", 14, Color(0.4, 0.38, 0.34)))
		col.add_child(ThemeFactory.label("0 slain", 13, Color(0.4, 0.38, 0.34)))
	return card
