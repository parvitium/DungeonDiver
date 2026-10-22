extends Node
## Authoritative session: profile, run, command inbox, and seeded RNG.
## Player submits PlayerCommand; this node applies it on its physics tick.

signal profile_changed
signal run_started
signal run_ended(victory: bool)
signal log_message(text: String, color: Color)

var profile: PlayerProfile = PlayerProfile.new()
var run: DungeonRunState = null
var ui_open: bool = false
var accept_local_input: bool = true
## Seeded wrapper around RandomNumberGenerator. Loot and combat rolls use this.
var rng: GameRNG = GameRNG.new(1)

var _command_inbox: Array[PlayerCommand] = []


func _ready() -> void:
	process_priority = 20
	reset_profile(false)


func reset_profile(emit_change: bool = true) -> void:
	profile = PlayerProfile.new()
	rng = GameRNG.new(1)
	_command_inbox.clear()
	profile.grant_starter_kit(ContentDB.items, rng)
	if emit_change:
		profile_changed.emit()


func submit_command(cmd: PlayerCommand) -> void:
	if cmd == null:
		return
	_command_inbox.append(cmd)


func pending_command_count() -> int:
	return _command_inbox.size()


func tick(delta: float) -> void:
	var pawn := _find_player()
	for cmd in _command_inbox:
		if pawn != null and pawn.has_method("apply_command"):
			pawn.apply_command(cmd, delta)
	_command_inbox.clear()


func _physics_process(delta: float) -> void:
	tick(delta)


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
	rng = GameRNG.new(run.seed_value)
	_command_inbox.clear()
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
	_command_inbox.clear()
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
	return LootGenerator.generate_from_table(table, ContentDB.items, run.effective_tier, rng)


func randf() -> float:
	return rng.randf()


func engine_rng() -> RandomNumberGenerator:
	return rng.engine()


func _find_player() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
