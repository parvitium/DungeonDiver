class_name TestContent
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("content")
	var items := Catalog.all_items()
	var monsters := Catalog.all_monsters()
	var dungeons := Catalog.all_dungeons()
	var tables := Catalog.all_loot_tables()
	t.assert_ge(float(items.size()), 8.0, "gear set")
	t.assert_ge(float(monsters.size()), 4.0, "3 types + boss")
	t.assert_ge(float(dungeons.size()), 2.0, "two dungeon types")
	t.assert_ge(float(tables.size()), 3.0, "loot tables")

	var bosses := 0
	var regular := 0
	var ids: Dictionary = {}
	for monster in monsters:
		t.assert_true(not String(monster.id).is_empty(), "monster id")
		t.assert_true(not ids.has(String(monster.id)), "unique monster id")
		ids[String(monster.id)] = true
		if monster.is_boss:
			bosses += 1
		else:
			regular += 1
	t.assert_ge(float(regular), 3.0, "three regular monsters")
	t.assert_ge(float(bosses), 1.0, "at least one boss")

	var table_ids: Dictionary = {}
	for table in tables:
		table_ids[String(table.id)] = table
	var item_ids: Dictionary = {}
	for item in items:
		item_ids[String(item.id)] = true
	for monster in monsters:
		t.assert_true(table_ids.has(String(monster.loot_table_id)), "%s loot table exists" % String(monster.id))
	for dungeon in dungeons:
		t.assert_true(table_ids.has(String(dungeon.loot_table_id)), "%s loot table exists" % String(dungeon.id))
		t.assert_true(ids.has(String(dungeon.boss_id)), "%s boss exists" % String(dungeon.id))
		t.assert_true(dungeon.monster_pool.size() > 0, "%s pool" % String(dungeon.id))
		for mid in dungeon.monster_pool:
			t.assert_true(ids.has(mid), "%s pool member %s" % [String(dungeon.id), mid])
	for table in tables:
		t.assert_eq(table.item_ids.size(), table.weights.size(), "%s weights align" % String(table.id))
		for item_id in table.item_ids:
			t.assert_true(item_ids.has(item_id), "table item %s exists" % item_id)

	var db := DDTest.autoload("ContentDB")
	var dummy_table := LootTable.new()
	dummy_table.id = &"sneaky"
	dummy_table.item_ids = PackedStringArray(["rusty_sword"])
	dummy_table.weights = PackedFloat32Array([1.0])
	t.assert_false(db.accepts_extra(dummy_table, &"item"), "loot table is not an item")
	t.assert_true(db.accepts_extra(dummy_table, &"loot_table"), "valid loot table")
	var blank_item := ItemDef.new()
	t.assert_false(db.accepts_extra(blank_item, &"item"), "item needs id and name")
	var relic: ItemDef = db.get_item(&"ashen_circlet")
	t.assert_true(relic != null, "ashen_circlet loaded from data/items")
	t.assert_true(ItemDef.is_valid_extra(relic), "ashen_circlet field-valid")
	t.assert_true(db.item_is_on_a_table(&"ashen_circlet"), "ashen_circlet obtainable")
	t.assert_true(db.accepts_extra(relic, &"item"), "ashen_circlet accepted as item")
	t.assert_false(db.accepts_extra(relic, &"monster"), "item is not a monster")
	return t
