class_name TestTown
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("town")
	_shop_prices(t)
	_shop_trade(t)
	_save_slots(t)
	_settings(t)
	_main_menu_copy(t)
	_pause_copy(t)
	_hub_town_layout(t)
	return t


static func _shop_prices(t: DDTest) -> void:
	var common := _gear("a", DD.Rarity.COMMON, 4, 1)
	var rare := _gear("b", DD.Rarity.RARE, 12, 4)
	t.assert_gt(float(Shop.sell_price(rare)), float(Shop.sell_price(common)), "rare sells for more")
	t.assert_gt(float(Shop.buy_price(common)), float(Shop.sell_price(common)), "buy markup")
	t.assert_ge(float(Shop.sell_price(common)), 1.0, "min sell")


static func _shop_trade(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	var content := DDTest.autoload("ContentDB")
	session.reset_profile(false)
	session.profile.gold = 80
	var loot := _gear("loot1", DD.Rarity.UNCOMMON, 6, 2)
	session.profile.inventory.add_item(loot)
	var bag_before: int = session.profile.inventory.items.size()
	var sold := Shop.sell(session.profile, "loot1")
	t.assert_gt(float(sold), 0.0, "sold for gold")
	t.assert_eq(session.profile.inventory.items.size(), bag_before - 1, "item left the pack")
	t.assert_eq(session.profile.shop_buyback.size(), 1, "buyback listed")
	var gold_after_sell: int = session.profile.gold
	t.assert_true(Shop.buyback(session.profile, 0), "buyback succeeds")
	t.assert_eq(session.profile.gold, gold_after_sell - sold, "buyback costs the sell price")
	t.assert_eq(session.profile.shop_buyback.size(), 0, "buyback consumed")

	Shop.ensure_stock(session.profile, content.items, 42)
	t.assert_eq(session.profile.shop_stock.size(), Shop.STOCK_SIZE, "rotating stock size")
	session.profile.progression.record_clear(&"crypt", 4)
	session.profile.shop_stock.clear()
	Shop.ensure_stock(session.profile, content.items, 42)
	t.assert_eq(session.profile.shop_depth, 4, "stock tracks best depth")
	var deep := session.profile.shop_stock[0] as ItemInstance
	t.assert_ge(float(deep.item_level), 4.0, "deeper stock is higher ilvl")
	session.reset_profile(false)


static func _save_slots(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	var saves := DDTest.autoload("SaveService")
	for i in range(1, DD.SAVE_SLOT_COUNT + 1):
		saves.clear_slot(i)
	session.reset_profile(false)
	saves.new_game_in_slot(2, "Mara")
	t.assert_eq(saves.active_slot, 2, "active slot")
	t.assert_eq(session.profile.display_name, "Mara", "named character")
	t.assert_true(saves.has_slot(2), "slot file exists")
	var empty: Dictionary = saves.peek_slot(1)
	t.assert_false(bool(empty.get("occupied", true)), "empty slot")
	var filled: Dictionary = saves.peek_slot(2)
	t.assert_true(bool(filled.get("occupied", false)), "occupied slot")
	t.assert_eq(str(filled.get("name", "")), "Mara", "summary name")
	t.assert_true(saves.summary_line(filled).contains("Mara"), "summary line")
	session.profile.gold = 199
	session.profile.progression.record_clear(&"cavern", 3)
	t.assert_true(saves.save_slot(2), "resave")
	session.reset_profile(false)
	t.assert_true(saves.load_slot(2), "load slot")
	t.assert_eq(session.profile.display_name, "Mara", "loaded name")
	t.assert_eq(session.profile.gold, 199, "loaded gold")
	t.assert_eq(session.profile.progression.best_depth(), 3, "loaded best depth")
	var payload := SaveCodec.payload_from_profile(session.profile)
	var decoded := SaveCodec.profile_from_payload(payload)
	t.assert_eq(decoded.gold, 199, "codec gold")
	saves.clear_slot(2)
	session.reset_profile(false)


static func _settings(t: DDTest) -> void:
	var settings := GameSettings.new()
	settings.music_volume = 0.2
	settings.sfx_volume = 0.4
	settings.fullscreen = true
	settings.msaa = 2
	settings.from_dict(settings.to_dict())
	t.assert_eq(settings.music_volume, 0.2, "music persisted")
	t.assert_eq(settings.sfx_volume, 0.4, "sfx persisted")
	t.assert_true(settings.fullscreen, "fullscreen flag")
	t.assert_eq(settings.msaa, 2, "msaa")
	t.assert_true("toggle_inventory" in GameSettings.BINDABLE, "pack bindable")
	t.assert_eq(GameSettings.action_label("toggle_bestiary"), "Bestiary", "bind label")


static func _main_menu_copy(t: DDTest) -> void:
	var script := FileAccess.get_file_as_string("res://src/world/main_menu.gd")
	t.assert_true(script.contains("New Game"), "new game")
	t.assert_true(script.contains("Load Game"), "load game")
	t.assert_true(script.contains("Settings"), "settings")
	t.assert_true(script.contains("Multiplayer"), "multiplayer")
	t.assert_true(script.contains("Coming soon"), "multiplayer placeholder")
	t.assert_true(script.contains("Exit Game"), "exit")
	t.assert_true(script.contains("Host (coming soon)"), "host stub")
	t.assert_true(script.contains("Join (coming soon)"), "join stub")
	t.assert_true(FileAccess.file_exists("res://scenes/main_menu.tscn"), "main menu scene")


static func _pause_copy(t: DDTest) -> void:
	var script := FileAccess.get_file_as_string("res://src/ui/pause_panel.gd")
	t.assert_true(script.contains("Resume"), "resume")
	t.assert_true(script.contains("Settings"), "pause settings")
	t.assert_true(script.contains("Main Menu"), "pause main menu")
	t.assert_true(script.contains("dungeon_context"), "dungeon pause context")
	t.assert_true(script.contains("not _in_dungeon()"), "save hub only")


static func _hub_town_layout(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		t.assert_true(false, "scene tree for town")
		return
	var hub_script := FileAccess.get_file_as_string("res://src/world/hub.gd")
	t.assert_true(hub_script.contains("Character"), "character door")
	t.assert_true(hub_script.contains("Loot / Pack"), "pack door")
	t.assert_true(hub_script.contains("Shop"), "shop door")
	t.assert_true(hub_script.contains("Main Menu"), "town main menu")
	var hub: Node = (load("res://src/world/hub.gd") as GDScript).new()
	tree.root.add_child(hub)
	if hub.get_child_count() == 0 and hub.has_method("_ready"):
		hub._ready()
	t.assert_true(hub.find_child("GoldLabel", true, false) != null, "town gold")
	t.assert_true(hub.find_child("DungeonSelect", true, false) != null, "dungeon overlay")
	t.assert_true(hub.find_child("Shop", true, false) != null, "shop overlay")
	t.assert_true(hub.find_child("Settings", true, false) != null, "settings overlay")
	t.assert_true(hub.find_child("Pause", true, false) != null, "pause overlay")
	if hub.has_method("open_dungeon_select"):
		hub.open_dungeon_select()
	var row := hub.find_child("DepthRow", true, false) as HBoxContainer
	t.assert_true(row != null, "depth row in dungeon select")
	hub.free()


static func _gear(id: String, rarity: DD.Rarity, attack: float, ilvl: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = id
	item.def_id = &"rusty_sword"
	item.display_name = "Test Blade"
	item.slot = DD.EquipSlot.WEAPON
	item.rarity = rarity
	item.item_level = ilvl
	item.stats = StatBlock.new(attack, 1, 0, 0, 0)
	return item
