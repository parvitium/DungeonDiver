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
	return t
