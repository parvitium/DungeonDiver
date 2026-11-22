extends Node
## Authoritative session: profile, run, command inbox, and seeded RNG streams.
## Player submits PlayerCommand; this node applies it on its physics tick
## (process_physics_priority 20, after pawns submit — same frame, no inbox lag).

signal profile_changed
signal run_started
signal run_ended(victory: bool)
signal log_message(text: String, color: Color)

const AI_RNG_SALT := 0xA11A1

var profile: PlayerProfile = PlayerProfile.new()
var run: DungeonRunState = null
var ui_open: bool = false
var accept_local_input: bool = true
## Seeded loot / combat / drop rolls. Independent of monster AI.
var rng: GameRNG = GameRNG.new(1)
## Seeded monster patrol / AI. Independent of loot.
var ai_rng: GameRNG = GameRNG.new(1)

var look_settings: LookSettings = LookSettings.new()
var game_settings: GameSettings = GameSettings.new()

var _command_inbox: Array[PlayerCommand] = []


func _init() -> void:
	# tick is _physics_process; lower physics priority runs first (pawns at 0).
	process_physics_priority = 20


func _enter_tree() -> void:
	process_physics_priority = 20


func _ready() -> void:
	process_physics_priority = 20
	reset_profile(false)
	look_settings.load_from_disk()
	game_settings.load_from_disk()


func reset_profile(emit_change: bool = true) -> void:
	profile = PlayerProfile.new()
	rng = GameRNG.new(1)
	ai_rng = GameRNG.new(_stream_seed(1, AI_RNG_SALT))
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
	ai_rng = GameRNG.new(_stream_seed(run.seed_value, AI_RNG_SALT))
	_command_inbox.clear()
	run_started.emit()
	log_message.emit("Entered %s (depth %d)." % [def.display_name, run.depth], Color(0.85, 0.75, 0.45))
	return run


func go_to_town() -> void:
	ui_open = true
	MouseCapture.apply(MouseCapture.Context.HUB)
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.paused = false
			tree.change_scene_to_file("res://scenes/hub.tscn")


func go_to_main_menu() -> void:
	if run != null:
		end_run(false)
	ui_open = true
	MouseCapture.apply(MouseCapture.Context.HUB)
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			tree.paused = false
			tree.change_scene_to_file("res://scenes/main_menu.tscn")


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
	SaveService.save_active()


func record_kill(monster_id: StringName) -> void:
	profile.progression.record_kill(monster_id)
	if run:
		run.kills_this_run += 1
	profile_changed.emit()


func restart_run() -> void:
	if run == null:
		return
	var dungeon_id := run.dungeon_id
	var depth := run.depth
	run = null
	_command_inbox.clear()
	profile.refill()
	start_run(dungeon_id, depth)


func use_item(instance_id: String) -> bool:
	if not profile.inventory.use_consumable(instance_id, profile):
		return false
	var pawn := _find_player()
	if pawn:
		pawn.set("health", profile.current_health)
		if pawn.has_signal("vitals_changed"):
			pawn.vitals_changed.emit()
	profile_changed.emit()
	SaveService.save_active()
	return true


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


func engine_ai_rng() -> RandomNumberGenerator:
	return ai_rng.engine()


static func _stream_seed(base: int, salt: int) -> int:
	var mixed := base ^ salt
	if mixed == 0:
		mixed = base + salt
	if mixed == 0:
		mixed = 1
	return mixed


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
