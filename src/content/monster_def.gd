class_name MonsterDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var is_boss: bool = false
@export var max_health: float = 40.0
@export var damage: float = 8.0
@export var move_speed: float = 3.2
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.2
@export var detect_range: float = 10.0
@export var lose_range: float = 16.0
@export var uses_ranged: bool = false
@export var projectile_speed: float = 14.0
@export var loot_table_id: StringName = &""
@export var drop_chance: float = 0.7
@export var color: Color = Color(0.7, 0.2, 0.2)
@export var scale: Vector3 = Vector3.ONE


static func is_valid_extra(resource: Variant) -> bool:
	if not resource is MonsterDef:
		return false
	var def: MonsterDef = resource
	if String(def.id).is_empty() or def.display_name.is_empty():
		return false
	if def.max_health <= 0.0 or def.damage < 0.0 or def.move_speed < 0.0:
		return false
	if def.attack_range < 0.0 or def.detect_range < 0.0:
		return false
	if def.drop_chance < 0.0 or def.drop_chance > 1.0:
		return false
	return true
