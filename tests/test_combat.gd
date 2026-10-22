class_name TestCombat
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("combat")
	var raw := CombatResolver.mitigated_damage(20.0, 0.0)
	t.assert_eq(raw, 20.0, "zero defense")
	var mitigated := CombatResolver.mitigated_damage(20.0, 100.0)
	t.assert_eq(mitigated, 10.0, "100 defense halves")
	t.assert_gt(CombatResolver.mitigated_damage(5.0, 999.0), 0.9, "minimum 1 damage")
	var blocked := CombatResolver.apply_block(20.0, true, 0.4)
	t.assert_eq(blocked, 8.0, "block factor")
	t.assert_eq(CombatResolver.apply_block(20.0, false), 20.0, "no block")
	var stats := StatBlock.new(6, 0, 0, 0, 10)
	t.assert_eq(CombatResolver.player_melee_power(stats), 16.0, "melee power")
	t.assert_gt(CombatResolver.player_spell_power(stats), 12.0, "spell uses spell power")
	t.assert_gt(CombatResolver.scaled_monster_health(40, 3), CombatResolver.scaled_monster_health(40, 1), "monster hp scales")
	t.assert_gt(CombatResolver.scaled_monster_damage(8, 3), CombatResolver.scaled_monster_damage(8, 1), "monster dmg scales")
	return t
