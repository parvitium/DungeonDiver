class_name DungeonRunState
extends RefCounted

var dungeon_id: StringName = &""
var depth: int = 1
var effective_tier: int = 1
var seed_value: int = 0
var blueprint: DungeonBlueprint = null
var boss_defeated: bool = false
var living_monsters: int = 0
