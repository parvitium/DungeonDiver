class_name TestStats
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("stats")
	var a := StatBlock.new(2, 3, 10, 4, 1)
	var b := StatBlock.new(1, 1, 5, 2, 2)
	var sum := a.add(b)
	t.assert_eq(sum.attack, 3.0, "add attack")
	t.assert_eq(sum.max_health, 15.0, "add health")
	var scaled := a.scaled(2.0)
	t.assert_eq(scaled.defense, 6.0, "scale defense")
	t.assert_eq(a.attack, 2.0, "scale does not mutate source")
	var copy := StatBlock.from_dict(a.to_dict())
	t.assert_eq(copy.spell_power, 1.0, "roundtrip spell")
	t.assert_true(a.summarize().contains("ATK"), "summarize lists attack")
	t.assert_eq(DD.effective_tier(1, 1), 1, "tier 1 depth 1")
	t.assert_eq(DD.effective_tier(1, 3), 3, "tier 1 depth 3")
	t.assert_eq(DD.effective_tier(2, 2), 3, "cavern depth 2")
	t.assert_gt(DD.depth_scale(3), DD.depth_scale(1), "deeper is stronger")
	t.assert_eq(DD.rarity_multiplier(DD.Rarity.COMMON), 1.0, "common mult")
	t.assert_gt(DD.rarity_multiplier(DD.Rarity.LEGENDARY), DD.rarity_multiplier(DD.Rarity.RARE), "legendary > rare")
	return t
