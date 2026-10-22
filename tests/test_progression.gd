class_name TestProgression
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("progression")
	var p := ProgressionState.new()
	t.assert_false(p.discovered(&"skeleton"), "unknown until kill")
	p.record_kill(&"skeleton")
	p.record_kill(&"skeleton")
	t.assert_eq(p.kills_of(&"skeleton"), 2, "kill count")
	t.assert_true(p.discovered(&"skeleton"), "discovered")
	p.record_clear(&"crypt", 1)
	p.record_clear(&"crypt", 3)
	p.record_clear(&"crypt", 2)
	t.assert_eq(p.highest_clear(&"crypt"), 3, "keeps best depth")
	t.assert_true(p.dungeon_conquered(&"crypt"), "conquered")
	t.assert_false(p.dungeon_conquered(&"cavern"), "other dungeon")
	var monsters := PackedStringArray(["skeleton", "wraith", "cave_wolf"])
	t.assert_eq(p.discovered_count(monsters), 1, "catalog count")
	var dungeons := PackedStringArray(["crypt", "cavern"])
	t.assert_eq(p.conquered_count(dungeons), 1, "dungeon count")
	var copy := ProgressionState.from_dict(p.to_dict())
	t.assert_eq(copy.kills_of(&"skeleton"), 2, "bestiary roundtrip")
	t.assert_eq(copy.highest_clear(&"crypt"), 3, "conquest roundtrip")
	return t
