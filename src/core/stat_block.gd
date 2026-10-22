class_name StatBlock
extends RefCounted
## Flat combat/vital stats. Authoritative simulation type — no Node dependency.

var attack: float = 0.0
var defense: float = 0.0
var max_health: float = 0.0
var max_stamina: float = 0.0
var spell_power: float = 0.0


func _init(
		p_attack: float = 0.0,
		p_defense: float = 0.0,
		p_max_health: float = 0.0,
		p_max_stamina: float = 0.0,
		p_spell_power: float = 0.0
	) -> void:
	attack = p_attack
	defense = p_defense
	max_health = p_max_health
	max_stamina = p_max_stamina
	spell_power = p_spell_power


func add(other: StatBlock) -> StatBlock:
	return StatBlock.new(
		attack + other.attack,
		defense + other.defense,
		max_health + other.max_health,
		max_stamina + other.max_stamina,
		spell_power + other.spell_power
	)


func scaled(multiplier: float) -> StatBlock:
	return StatBlock.new(
		_scale_stat(attack, multiplier),
		_scale_stat(defense, multiplier),
		_scale_stat(max_health, multiplier),
		_scale_stat(max_stamina, multiplier),
		_scale_stat(spell_power, multiplier)
	)


func _scale_stat(value: float, multiplier: float) -> float:
	if is_zero_approx(value):
		return 0.0
	return snappedf(value * multiplier, 0.1)


func to_dict() -> Dictionary:
	return {
		"attack": attack,
		"defense": defense,
		"max_health": max_health,
		"max_stamina": max_stamina,
		"spell_power": spell_power,
	}


static func from_dict(data: Variant) -> StatBlock:
	if data == null:
		return StatBlock.new()
	if not data is Dictionary:
		return null
	var dict: Dictionary = data
	var values: Dictionary = {}
	for key in ["attack", "defense", "max_health", "max_stamina", "spell_power"]:
		if dict.has(key):
			if not DD.is_number(dict[key]):
				return null
			values[key] = float(dict[key])
		else:
			values[key] = 0.0
	return StatBlock.new(
		values["attack"],
		values["defense"],
		values["max_health"],
		values["max_stamina"],
		values["spell_power"]
	)


func duplicate_stats() -> StatBlock:
	return StatBlock.new(attack, defense, max_health, max_stamina, spell_power)


func summarize() -> String:
	var parts: PackedStringArray = []
	if attack != 0.0:
		parts.append("ATK %+0.1f" % attack)
	if defense != 0.0:
		parts.append("DEF %+0.1f" % defense)
	if max_health != 0.0:
		parts.append("HP %+0.1f" % max_health)
	if max_stamina != 0.0:
		parts.append("STA %+0.1f" % max_stamina)
	if spell_power != 0.0:
		parts.append("SP %+0.1f" % spell_power)
	return ", ".join(parts) if not parts.is_empty() else "No bonuses"
