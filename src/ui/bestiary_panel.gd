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
	dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := ThemeFactory.centered_sheet(self, Vector2(760, 520))
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 12
	root.offset_right = -16
	root.offset_bottom = -12
	panel.add_child(root)

	var monsters := ContentDB.monster_ids()
	var dungeons := ContentDB.dungeon_ids()
	var found := GameSession.profile.progression.discovered_count(monsters)
	var clears := GameSession.profile.progression.conquered_count(dungeons)
	root.add_child(ThemeFactory.label("Bestiary & Conquest Log", 26, Color(0.95, 0.82, 0.45)))
	root.add_child(ThemeFactory.label("Goal: defeat every monster type and conquer every dungeon.", 14, Color(0.75, 0.7, 0.58)))
	root.add_child(ThemeFactory.label("Catalogued  %d / %d monsters     Conquered  %d / %d dungeons" % [found, monsters.size(), clears, dungeons.size()], 16, Color(0.85, 0.78, 0.5)))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var beast := VBoxContainer.new()
	beast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beast.add_child(ThemeFactory.label("Monsters", 18))
	for monster_id in monsters:
		var def: MonsterDef = ContentDB.get_monster(monster_id)
		var kills := GameSession.profile.progression.kills_of(monster_id)
		var title := def.display_name if kills > 0 else "???"
		var extra := def.description if kills > 0 else "Not yet encountered."
		var kind := "???"
		if kills > 0:
			kind = "Boss" if def.is_boss else "Beast"
		beast.add_child(ThemeFactory.label("%s  ·  %s  ·  %d slain" % [title, kind, kills], 15, Color(0.92, 0.86, 0.7) if kills > 0 else Color(0.45, 0.42, 0.38)))
		beast.add_child(ThemeFactory.label(extra, 13, Color(0.65, 0.6, 0.5)))
	cols.add_child(beast)

	var log := VBoxContainer.new()
	log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log.add_child(ThemeFactory.label("Dungeons", 18))
	for dungeon_id in dungeons:
		var def: DungeonTypeDef = ContentDB.get_dungeon(dungeon_id)
		var depth := GameSession.profile.progression.highest_clear(dungeon_id)
		var status := "Unconquered"
		if depth > 0:
			status = "Cleared to depth %d" % depth
		log.add_child(ThemeFactory.label(def.display_name, 16, Color(0.9, 0.8, 0.5)))
		log.add_child(ThemeFactory.label("%s — %s" % [status, def.description], 13, Color(0.7, 0.65, 0.52)))
	cols.add_child(log)
