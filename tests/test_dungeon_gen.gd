class_name TestDungeonGen
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("dungeon_gen")
	var defs := Catalog.all_dungeons()
	t.assert_ge(float(defs.size()), 2.0, "at least two dungeon types")
	for def in defs:
		var blueprint := DungeonGenerator.generate(def, 1, 12345)
		t.assert_ge(float(blueprint.rooms.size()), 4.0, "%s layout size" % String(def.id))
		t.assert_true(blueprint.layout_is_connected(), "%s connected" % String(def.id))
		t.assert_true(blueprint.has_boss_and_exit(), "%s boss+exit" % String(def.id))
		t.assert_eq(String(blueprint.dungeon_id), String(def.id), "id stamped")
		t.assert_true(blueprint.start_room() != null, "start exists")
		t.assert_eq(blueprint.start_room().kind, DD.RoomKind.START, "start kind")
		var boss := blueprint.room_at(blueprint.boss_cell)
		t.assert_true(boss != null and boss.monster_ids.size() > 0, "boss spawn")
		t.assert_eq(boss.monster_ids[0], String(def.boss_id), "boss id")
		var same := DungeonGenerator.generate(def, 1, 12345)
		t.assert_eq(same.rooms.size(), blueprint.rooms.size(), "seeded size stable")
		t.assert_eq(same.boss_cell, blueprint.boss_cell, "seeded boss stable")

	var crypt := defs[0]
	var d1 := DungeonGenerator.generate(crypt, 1, 9)
	var d3 := DungeonGenerator.generate(crypt, 3, 9)
	t.assert_gt(float(d3.effective_tier), float(d1.effective_tier), "depth raises tier")
	return t
