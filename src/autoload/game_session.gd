extends Node
## Authoritative session: profile + current run. Presentation reads this.
## Future host will own this node; clients will send PlayerCommand only.

signal profile_changed
signal run_started
signal run_ended(victory: bool)
signal log_message(text: String, color: Color)

var profile: PlayerProfile = PlayerProfile.new()
var run: DungeonRunState = null
var ui_open: bool = false


func _ready() -> void:
	reset_profile(false)


func reset_profile(emit_change: bool = true) -> void:
	profile = PlayerProfile.new()
	var rng := GameRNG.new(1)
	profile.grant_starter_kit(ContentDB.items, rng)
	if emit_change:
		profile_changed.emit()


func start_run(dungeon_id: StringName, depth: int, seed_value: int = 0) -> DungeonRunState:
	var def: DungeonTypeDef = ContentDB.get_dungeon(dungeon_id)
	if def == null:
		push_error("Unknown dungeon: %s" % String(dungeon_id))
		return null
	profile.refill()
	run = DungeonRunState.new()
	run.dungeon_id = def.id
	run.depth = maxi(1, depth)
	run.effective_tier = DD.effective_tier(def.base_tier, run.depth)
	run.seed_value = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	run.blueprint = DungeonGenerator.generate(def, run.depth, run.seed_value)
	run.blueprint.effective_tier = run.effective_tier
	run_started.emit()
	log_message.emit("Entered %s (depth %d)." % [def.display_name, run.depth], Color(0.85, 0.75, 0.45))
	return run


func end_run(victory: bool) -> void:
	if run == null:
		return
	if victory:
		profile.progression.record_clear(run.dungeon_id, run.depth)
		log_message.emit("Dungeon conquered.", Color(0.7, 0.95, 0.55))
	else:
		log_message.emit("Retreated to the surface.", Color(0.9, 0.55, 0.4))
	run = null
	profile.refill()
	profile_changed.emit()
	run_ended.emit(victory)
	SaveService.save_game()


func record_kill(monster_id: StringName) -> void:
	profile.progression.record_kill(monster_id)
	profile_changed.emit()


func give_loot(items: Array[ItemInstance]) -> void:
	for item in items:
		profile.inventory.add_item(item)
		log_message.emit("Loot: %s" % item.full_name(), DD.rarity_color(item.rarity))
	profile_changed.emit()


func roll_table(table_id: StringName) -> Array[ItemInstance]:
	if run == null:
		return []
	var table: LootTable = ContentDB.get_loot_table(table_id)
	var rng := GameRNG.new(run.seed_value + int(Time.get_ticks_usec() % 997))
	return LootGenerator.generate_from_table(table, ContentDB.items, run.effective_tier, rng)
