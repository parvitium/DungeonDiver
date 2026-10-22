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
