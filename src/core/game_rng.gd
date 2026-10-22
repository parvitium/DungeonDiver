class_name GameRNG
extends RefCounted
## Seeded RNG wrapper so dungeon/loot rolls stay deterministic and host-owned.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0


func _init(p_seed: int = 0) -> void:
	reseed(p_seed)


func reseed(p_seed: int) -> void:
	seed_value = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system())
	_rng.seed = seed_value


func randf() -> float:
	return _rng.randf()


func randf_range(from_value: float, to_value: float) -> float:
	return _rng.randf_range(from_value, to_value)


func randi_range(from_value: int, to_value: int) -> int:
	return _rng.randi_range(from_value, to_value)


func pick_weighted(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(0.0, w)
	if total <= 0.0:
		return 0
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += maxf(0.0, weights[i])
		if roll <= acc:
			return i
	return weights.size() - 1


func pick_weighted_ids(ids: PackedStringArray, weights: PackedFloat32Array) -> String:
	if ids.is_empty():
		return ""
	if weights.size() != ids.size():
		return ids[_rng.randi_range(0, ids.size() - 1)]
	return ids[pick_weighted(weights)]


func shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp
