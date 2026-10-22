class_name CombatResolver
extends RefCounted
## Pure damage math. Safe to call from tests and from the server later.


static func mitigated_damage(raw_attack: float, defense: float) -> float:
	var safe_attack := maxf(0.0, raw_attack)
	var safe_defense := maxf(0.0, defense)
	var mitigated := safe_attack * (100.0 / (100.0 + safe_defense))
	return maxf(1.0, snappedf(mitigated, 0.1))


static func apply_block(damage: float, blocking: bool, block_factor: float = 0.4) -> float:
	if not blocking:
		return damage
	return maxf(1.0, snappedf(damage * clampf(block_factor, 0.05, 1.0), 0.1))


static func player_melee_power(stats: StatBlock) -> float:
	return 10.0 + stats.attack


static func player_spell_power(stats: StatBlock) -> float:
	return 12.0 + stats.spell_power * 0.85 + stats.attack * 0.15


static func scaled_monster_health(base_health: float, effective_tier: int) -> float:
	return snappedf(base_health * DD.depth_scale(effective_tier), 1.0)


static func scaled_monster_damage(base_damage: float, effective_tier: int) -> float:
	return snappedf(base_damage * DD.depth_scale(effective_tier), 0.1)
