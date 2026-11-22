extends Control
## Town shop: sell loot, buyback, and rotating stock scaled by best depth.

var _status: Label
var _sell_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	resized.connect(_fit_modal)
	refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	visible = false


func _fit_modal() -> void:
	var panel := find_child("PackPanel", true, false) as Control
	if panel:
		ThemeFactory.fit_modal_panel(self, panel)


func refresh() -> void:
	var keep := _sell_id
	while get_child_count() > 0:
		get_child(0).free()
	_sell_id = keep
	Shop.ensure_stock(GameSession.profile, ContentDB.items, SaveService.active_slot * 97 + 11)
	var panel := ThemeFactory.mount_modal(self, true, 0.92, 0.9)
	_fit_modal()
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(inner)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	inner.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := ThemeFactory.label("Shop", 26, Color(0.95, 0.82, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(ThemeFactory.label("%d gold" % GameSession.profile.gold, 20, Color(0.95, 0.82, 0.35)))
	header.add_child(ThemeFactory.close_button(close))
	_status = ThemeFactory.label("Sell loot by rarity and stats. Stock scales with your best depth.", 14, Color(0.75, 0.7, 0.55), true)
	root.add_child(_status)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)
	cols.add_child(_column("For sale", _stock_rows(), 1.1))
	cols.add_child(_column("Your pack", _sell_rows(), 1.0))
	cols.add_child(_column("Buyback", _buyback_rows(), 0.85))


func _column(title: String, rows: Array, stretch: float) -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_stretch_ratio = stretch
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(ThemeFactory.label(title, 18, Color(0.95, 0.82, 0.45)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	if rows.is_empty():
		list.add_child(ThemeFactory.label("Nothing here.", 14, Color(0.65, 0.6, 0.5)))
	else:
		for row in rows:
			list.add_child(row)
	return wrap


func _stock_rows() -> Array:
	var out: Array = []
	for i in GameSession.profile.shop_stock.size():
		var item: ItemInstance = GameSession.profile.shop_stock[i]
		var price := Shop.buy_price(item)
		out.append(_item_row(item, "Buy  %d" % price, GameSession.profile.gold >= price, _buy_stock.bind(i)))
	return out


func _sell_rows() -> Array:
	var out: Array = []
	var inv := GameSession.profile.inventory
	var listed: Dictionary = {}
	for worn in inv.equipped:
		if worn is ItemInstance and not listed.has(worn.instance_id):
			listed[worn.instance_id] = true
			var price := Shop.sell_price(worn)
			out.append(_item_row(worn, "Sell  %d" % price, true, _sell_item.bind(worn.instance_id)))
	for item in inv.items:
		if listed.has(item.instance_id):
			continue
		var price := Shop.sell_price(item)
		out.append(_item_row(item, "Sell  %d" % price, true, _sell_item.bind(item.instance_id)))
	return out


func _buyback_rows() -> Array:
	var out: Array = []
	for i in GameSession.profile.shop_buyback.size():
		var item: ItemInstance = GameSession.profile.shop_buyback[i]
		var price := Shop.sell_price(item)
		out.append(_item_row(item, "Buy back  %d" % price, GameSession.profile.gold >= price, _buy_back.bind(i)))
	return out


func _buy_stock(index: int) -> void:
	if Shop.buy_from_stock(GameSession.profile, index):
		GameSession.profile_changed.emit()
		refresh()
	elif _status:
		_status.text = "Not enough gold."


func _sell_item(instance_id: String) -> void:
	if Shop.sell(GameSession.profile, instance_id) > 0:
		GameSession.profile_changed.emit()
		refresh()


func _buy_back(index: int) -> void:
	if Shop.buyback(GameSession.profile, index):
		GameSession.profile_changed.emit()
		refresh()
	elif _status:
		_status.text = "Not enough gold."


func _item_row(item: ItemInstance, action: String, enabled: bool, cb: Callable) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	box_style.border_color = DD.rarity_color(item.rarity)
	box_style.set_border_width_all(1)
	box_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", box_style)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8
	inner.offset_top = 6
	inner.offset_right = -8
	inner.offset_bottom = -6
	card.add_child(inner)
	inner.add_child(ThemeFactory.label(item.full_name(), 14, DD.rarity_color(item.rarity)))
	var stats := item.stats
	var line := "ilvl %d" % item.item_level
	if stats:
		line += "  ATK %d  DEF %d" % [int(stats.attack), int(stats.defense)]
	inner.add_child(ThemeFactory.label(line, 12, Color(0.75, 0.7, 0.58)))
	var btn := Button.new()
	btn.text = action
	btn.disabled = not enabled
	ThemeFactory.apply_button(btn)
	btn.pressed.connect(cb)
	inner.add_child(btn)
	return card
