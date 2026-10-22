class_name DungeonTypeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var base_tier: int = 1
@export var min_rooms: int = 5
@export var max_rooms: int = 8
@export var monster_pool: PackedStringArray = []
@export var monster_weights: PackedFloat32Array = []
@export var boss_id: StringName = &""
@export var loot_table_id: StringName = &""
@export var chest_chance: float = 0.35
@export var floor_color: Color = Color(0.22, 0.20, 0.18)
@export var wall_color: Color = Color(0.16, 0.15, 0.14)
@export var accent_color: Color = Color(0.55, 0.35, 0.75)
@export var fog_color: Color = Color(0.05, 0.04, 0.06)
@export var light_color: Color = Color(0.75, 0.55, 1.0)


static func is_valid_extra(resource: Variant) -> bool:
	if not resource is DungeonTypeDef:
		return false
	var def: DungeonTypeDef = resource
	if String(def.id).is_empty() or def.display_name.is_empty():
		return false
	if def.min_rooms < 1 or def.max_rooms < def.min_rooms:
		return false
	if def.base_tier < 1:
		return false
	if String(def.boss_id).is_empty():
		return false
	return true
