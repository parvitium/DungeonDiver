extends Node3D
## Builds a generated dungeon, spawns entities, and owns run-local events.

var _player: Player
var _hud: CanvasLayer
var _exit: Interactable
var _alive_monsters: int = 0
var _death: CanvasLayer


func _ready() -> void:
	if GameSession.run == null:
		GameSession.start_run(&"crypt", 1, 42)
	var def: DungeonTypeDef = ContentDB.get_dungeon(GameSession.run.dungeon_id)
	var builder := DungeonBuilder.new()
	var markers: Dictionary = builder.build(self, GameSession.run.blueprint, def)
	var vfx := CombatVfx.new()
	add_child(vfx)
	_spawn_player(markers["player"])
	_spawn_monsters(markers["spawns"])
	_spawn_chests(markers["chests"])
	_spawn_exit(markers["exit"])
	_hud = preload("res://src/ui/hud.gd").new()
	add_child(_hud)
	_hud.bind_player(_player)
	_death = preload("res://src/ui/death_overlay.gd").new()
	add_child(_death)
	_death.retry_pressed.connect(_on_retry)
	_death.menu_pressed.connect(_on_main_menu)
	GameSession.ui_open = false
	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
	call_deferred("_ensure_capture")


func _ensure_capture() -> void:
	if GameSession.ui_open:
		return
	MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)


func _spawn_player(at: Vector3) -> void:
	_player = Player.new()
	add_child(_player)
	_player.global_position = at
	_player.died.connect(_on_player_died)


func _spawn_monsters(spawns: Array) -> void:
	_alive_monsters = 0
	for spawn in spawns:
		var def: MonsterDef = ContentDB.get_monster(StringName(str(spawn["id"])))
		if def == null:
			continue
		var mob := Monster.new()
		add_child(mob)
		mob.setup(def, GameSession.run.effective_tier)
		mob.global_position = spawn["position"]
		mob.sync_home()
		mob.died.connect(_on_monster_died)
		_alive_monsters += 1
	GameSession.run.living_monsters = _alive_monsters


func _spawn_chests(positions: Array) -> void:
	for pos in positions:
		var chest := LootChest.new()
		chest.chest_key = LootChest.key_for(pos)
		add_child(chest)
		chest.global_position = pos
		chest.activated.connect(_on_chest_opened.bind(chest))


func _spawn_exit(at: Variant) -> void:
	if at == null:
		return
	var pos := Vector3.ZERO
	var inward := Vector3(0, 0, -1)
	if at is Dictionary:
		pos = at.get("position", Vector3.ZERO)
		inward = at.get("inward", inward)
	elif at is Vector3:
		pos = at
	var gate := ExitGate.new()
	add_child(gate)
	gate.global_position = pos
	if inward.length() > 0.01:
		gate.look_at(pos + inward, Vector3.UP)
	gate.set_locked_state(true)
	gate.activated.connect(_on_exit_used)
	_exit = gate
	if GameSession.run and GameSession.run.boss_defeated:
		gate.set_locked_state(false)


func _on_monster_died(monster: Monster) -> void:
	_alive_monsters = maxi(0, _alive_monsters - 1)
	GameSession.run.living_monsters = _alive_monsters
	GameSession.record_kill(monster.def.id)
	if monster.def.drop_chance >= 1.0 or GameSession.randf() <= monster.def.drop_chance:
		var loot := GameSession.roll_table(monster.def.loot_table_id)
		for item in loot:
			var drop := LootDrop.new()
			add_child(drop)
			drop.setup(item)
			drop.global_position = monster.global_position + Vector3(0, 0.2, 0)
	if monster.def.is_boss:
		GameSession.run.boss_defeated = true
		if _exit:
			if _exit.has_method("set_locked_state"):
				_exit.set_locked_state(false)
			else:
				_exit.locked = false
			GameSession.log_message.emit("The gate unlocks.", Color(0.55, 1.0, 0.8))


func _on_chest_opened(_by: Node, chest: Interactable) -> void:
	var table_id := &"chest_drops"
	if GameSession.run != null:
		var dungeon: DungeonTypeDef = ContentDB.get_dungeon(GameSession.run.dungeon_id)
		if dungeon != null and not String(dungeon.loot_table_id).is_empty():
			table_id = dungeon.loot_table_id
	var loot := GameSession.roll_table(table_id)
	for i in loot.size():
		var drop := LootDrop.new()
		add_child(drop)
		drop.setup(loot[i])
		drop.global_position = chest.global_position + Vector3(0.4 * float(i), 0.3, 0.4)


func _on_exit_used(_by: Node) -> void:
	GameSession.end_run(true)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _on_player_died() -> void:
	GameSession.log_message.emit("You fall in the dark.", Color(1.0, 0.3, 0.25))
	var dungeon_name := "the dungeon"
	var depth := 1
	var kills := 0
	if GameSession.run:
		var def: DungeonTypeDef = ContentDB.get_dungeon(GameSession.run.dungeon_id)
		if def:
			dungeon_name = def.display_name
		depth = GameSession.run.depth
		kills = GameSession.run.kills_this_run
	var lost := GameSession.apply_death_penalty()
	if _hud and _hud.has_method("close_panels"):
		_hud.close_panels()
	if _death:
		_death.present({"dungeon": dungeon_name, "depth": depth, "kills": kills, "lost": lost})


func _on_retry() -> void:
	GameSession.restart_run()
	get_tree().change_scene_to_file("res://scenes/dungeon_run.tscn")


func _on_main_menu() -> void:
	GameSession.end_run(false)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
