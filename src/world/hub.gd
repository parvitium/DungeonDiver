extends Node3D
## Town hub reached after New or Load. Closable sub-screens keep the dungeon-card look.

var _ui: Control
var _depth: int = 1
var _selected: StringName = &"crypt"
var _load_notice: String = ""
var _inv: Control
var _best: Control
var _shop: Control
var _dungeon: Control
var _settings: Control
var _pause: Control
var _gold: Label
var _built: bool = false


func _ready() -> void:
	if _built:
		return
	_built = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSession.ui_open = true
	GameSession.run = null
	MouseCapture.apply(MouseCapture.Context.HUB)
	var seed := 11
	if SaveService:
		seed = SaveService.active_slot * 97 + 11
	Shop.ensure_stock(GameSession.profile, ContentDB.items, seed)
	ScenicBackdrop.attach(self, 8.6)
	_build_ui()


func load_notice_text() -> String:
	return _load_notice


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.name = "TownUI"
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_inv = preload("res://src/ui/inventory_panel.gd").new()
	_inv.name = "Inv"
	_inv.visible = false
	_best = preload("res://src/ui/bestiary_panel.gd").new()
	_best.name = "Best"
	_best.visible = false
	_shop = preload("res://src/ui/shop_panel.gd").new()
	_shop.name = "Shop"
	_shop.visible = false
	_dungeon = Control.new()
	_dungeon.name = "DungeonSelect"
	_dungeon.visible = false
	_dungeon.process_mode = Node.PROCESS_MODE_ALWAYS
	_dungeon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dungeon.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings = preload("res://src/ui/settings_panel.gd").new()
	_settings.name = "Settings"
	_settings.visible = false
	_pause = preload("res://src/ui/pause_panel.gd").new()
	_pause.name = "Pause"
	_pause.visible = false
	_refresh_ui()
	_refresh_dungeon_overlay()
	_ui.add_child(_inv)
	_ui.add_child(_best)
	_ui.add_child(_shop)
	_ui.add_child(_dungeon)
	_ui.add_child(_settings)
	_ui.add_child(_pause)


func _refresh_ui() -> void:
	if _ui == null:
		return
	var doomed: Array = []
	for child in _ui.get_children():
		if child in [_inv, _best, _shop, _dungeon, _settings, _pause]:
			continue
		doomed.append(child)
	for child in doomed:
		child.free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	_ui.add_child(margin)
	_ui.move_child(margin, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(ThemeFactory.label("Town", 42, Color(0.95, 0.82, 0.42)))
	titles.add_child(ThemeFactory.label("%s  ·  rest, trade, then pick a dungeon." % GameSession.profile.display_name, 16, Color(0.8, 0.74, 0.6), true))
	header.add_child(titles)
	_gold = ThemeFactory.label("%d gold" % GameSession.profile.gold, 22, Color(0.95, 0.82, 0.35))
	_gold.name = "GoldLabel"
	header.add_child(_gold)
	if not _load_notice.is_empty():
		root.add_child(ThemeFactory.label(_load_notice, 16, Color(0.95, 0.55, 0.4), true))

	var monsters := ContentDB.monster_ids()
	var dungeons := ContentDB.dungeon_ids()
	var found := GameSession.profile.progression.discovered_count(monsters)
	var clears := GameSession.profile.progression.conquered_count(dungeons)
	root.add_child(ThemeFactory.label("Collection  %d/%d monsters   %d/%d dungeons   best depth %d" % [
		found, monsters.size(), clears, dungeons.size(), GameSession.profile.progression.best_depth()
	], 16, Color(0.85, 0.75, 0.5)))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	grid.add_child(_place("Character", "Edit name, inspect stats, and equip gear.", _open_character))
	grid.add_child(_place("Loot / Pack", "Bag overflow, filters, and compare.", _open_inv))
	grid.add_child(_place("Bestiary", "Monster log of kills, stats, and weaknesses.", _open_bestiary))
	grid.add_child(_place("Dungeon", "Pick a dungeon, then a floor depth.", _open_dungeon))
	grid.add_child(_place("Shop", "Sell loot, buyback, and rotating stock.", _open_shop))
	grid.add_child(_place("Save Game", "Write this town visit to the current slot.", _save_game))

	var actions := HBoxContainer.new()
	actions.name = "ActionsRow"
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	actions.add_child(_btn("Main Menu", _to_main_menu))
	var hint := ThemeFactory.label("Esc pause  ·  I pack  ·  B bestiary", 14, Color(0.7, 0.65, 0.55))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	actions.add_child(hint)


func _place(title: String, blurb: String, cb: Callable) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(280, 110)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", ThemeFactory.panel())
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_bottom", 12)
	card.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	inner.add_child(box)
	box.add_child(ThemeFactory.label(title, 22, Color(0.95, 0.82, 0.45)))
	var desc := ThemeFactory.label(blurb, 14, Color(0.75, 0.7, 0.58), true)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	var btn := Button.new()
	btn.text = "Open"
	if title == "Save Game":
		btn.text = "Save"
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	box.add_child(btn)
	return card


func _refresh_dungeon_overlay() -> void:
	if _dungeon == null:
		return
	while _dungeon.get_child_count() > 0:
		_dungeon.get_child(0).free()
	var panel := ThemeFactory.mount_modal(_dungeon, true, 0.94, 0.92)
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(inner)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	inner.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := ThemeFactory.label("Choose a dungeon", 26, Color(0.95, 0.82, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(ThemeFactory.close_button(_close_dungeon))
	root.add_child(ThemeFactory.label("Select a hall, then a floor depth. Higher depth is harder, with better loot.", 14, Color(0.75, 0.7, 0.55), true))
	var row := HBoxContainer.new()
	row.name = "DungeonRow"
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for dungeon_id in ContentDB.dungeon_ids():
		row.add_child(_dungeon_card(ContentDB.get_dungeon(dungeon_id)))
	root.add_child(_depth_section())


func _dungeon_card(def: DungeonTypeDef) -> Panel:
	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(300, 220)
	card.add_theme_stylebox_override("panel", ThemeFactory.panel())
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_top", 14)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_bottom", 14)
	card.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	inner.add_child(box)
	box.add_child(ThemeFactory.label(def.display_name, 22, def.accent_color.lightened(0.2)))
	box.add_child(ThemeFactory.label("Base tier %d" % def.base_tier, 14, Color(0.78, 0.72, 0.58)))
	var desc := ThemeFactory.label(def.description, 14, Color(0.75, 0.7, 0.58), true)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	var cleared := GameSession.profile.progression.highest_clear(def.id)
	box.add_child(ThemeFactory.label("Best clear: depth %d" % cleared if cleared > 0 else "Not yet conquered", 14, Color(0.7, 0.85, 0.55) if cleared > 0 else Color(0.6, 0.55, 0.45)))
	var enter := Button.new()
	enter.text = "Enter at depth %d" % _depth if _selected == def.id else "Select"
	ThemeFactory.apply_button(enter, _selected == def.id)
	enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter.pressed.connect(_select_or_enter.bind(def.id))
	box.add_child(enter)
	return card


func _depth_section() -> Control:
	var section := VBoxContainer.new()
	section.name = "DepthSection"
	section.add_theme_constant_override("separation", 8)
	section.add_child(ThemeFactory.label("Floor depth", 18, Color(0.95, 0.82, 0.45)))
	section.add_child(ThemeFactory.label("How far in you enter. Higher depth is harder, with better loot.", 14, Color(0.72, 0.66, 0.52), true))
	var row := HBoxContainer.new()
	row.name = "DepthRow"
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	for d in range(1, 4):
		var btn := Button.new()
		btn.name = "Depth%d" % d
		btn.text = "Depth %d" % d
		btn.tooltip_text = "Enter dungeons at floor depth %d." % d
		btn.custom_minimum_size = Vector2(148, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ThemeFactory.apply_button(btn, d == _depth)
		btn.pressed.connect(_set_depth.bind(d))
		row.add_child(btn)
	return section


func _btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(132, 40)
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	return btn


func _set_depth(value: int) -> void:
	_depth = value
	_refresh_dungeon_overlay()


func _select_or_enter(id: StringName) -> void:
	if _selected != id:
		_selected = id
		_refresh_dungeon_overlay()
		return
	GameSession.start_run(id, _depth)
	get_tree().change_scene_to_file("res://scenes/dungeon_run.tscn")


func _close_overlays() -> void:
	if _inv and _inv.has_method("close"):
		_inv.close()
	else:
		if _inv:
			_inv.visible = false
	if _best and _best.has_method("close"):
		_best.close()
	else:
		if _best:
			_best.visible = false
	if _shop and _shop.has_method("close"):
		_shop.close()
	if _dungeon:
		_dungeon.visible = false
	if _settings:
		_settings.return_to = null
		_settings.visible = false
	if _pause:
		_pause.visible = false


func _close_dungeon() -> void:
	if _dungeon:
		_dungeon.visible = false


func _open_character() -> void:
	_close_overlays()
	_inv.heading = "Character"
	_inv.show_name_editor = true
	_inv.visible = true
	_inv.refresh()


func _open_inv() -> void:
	if _inv.visible:
		_inv.close()
		return
	_close_overlays()
	_inv.heading = "Loot / Pack"
	_inv.show_name_editor = false
	_inv.visible = true
	_inv.refresh()


func _open_bestiary() -> void:
	if _best.visible:
		_best.close()
		return
	_close_overlays()
	_best.visible = true
	_best.refresh()


func _open_dungeon() -> void:
	if _dungeon.visible:
		_dungeon.visible = false
		return
	_close_overlays()
	_refresh_dungeon_overlay()
	_dungeon.visible = true


func _open_shop() -> void:
	if _shop.visible:
		_shop.close()
		return
	_close_overlays()
	_shop.visible = true
	_shop.refresh()


func _open_settings() -> void:
	_close_overlays()
	_settings.present(_pause if _pause and _pause.visible else null)


func _open_pause() -> void:
	if _pause.visible:
		_pause.visible = false
		return
	_close_overlays()
	_pause.visible = true
	if _pause.has_method("refresh"):
		_pause.refresh()


func _save_game() -> void:
	if SaveService.save_active():
		_load_notice = "Town saved to slot %d." % SaveService.active_slot
	else:
		_load_notice = "Save failed."
	_refresh_ui()


func _to_main_menu() -> void:
	SaveService.save_active()
	GameSession.go_to_main_menu()


func _try_continue() -> void:
	if SaveService.has_save():
		_apply_load_result(SaveService.load_game())


func _apply_load_result(ok: bool) -> void:
	if ok:
		_load_notice = ""
	else:
		_load_notice = SaveService.load_failure_message()


func _load_pressed() -> void:
	if not SaveService.has_save():
		_load_notice = "No save to load."
		_refresh_ui()
		return
	_apply_load_result(SaveService.load_game())
	_refresh_ui()


func _new_game() -> void:
	_load_notice = ""
	GameSession.reset_profile()
	SaveService.clear_save()
	_refresh_ui()


func open_character() -> void:
	_open_character()


func open_pack() -> void:
	_open_inv()


func open_bestiary_view() -> void:
	_open_bestiary()


func open_dungeon_select() -> void:
	_open_dungeon()


func open_shop() -> void:
	_open_shop()


func open_settings() -> void:
	_open_settings()


func open_pause() -> void:
	_open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_open_inv()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_bestiary"):
		_open_bestiary()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		if _overlay_open():
			_close_overlays()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()


func _overlay_open() -> bool:
	return (
		(_inv and _inv.visible)
		or (_best and _best.visible)
		or (_shop and _shop.visible)
		or (_dungeon and _dungeon.visible)
		or (_settings and _settings.visible)
	)
