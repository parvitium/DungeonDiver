extends Node3D
## Builds a generated dungeon, spawns entities, and owns run-local events.

var _player: Player
var _hud: CanvasLayer
var _exit: Interactable
var _alive_monsters: int = 0


func _ready() -> void:
	if GameSession.run == null:
		GameSession.start_run(&"crypt", 1, 42)
	var def: DungeonTypeDef = ContentDB.get_dungeon(GameSession.run.dungeon_id)
	var builder := DungeonBuilder.new()
	var markers: Dictionary = builder.build(self, GameSession.run.blueprint, def)
	_spawn_player(markers["player"], float(markers.get("player_yaw", 0.0)))
	_spawn_monsters(markers["spawns"])
	_spawn_chests(markers["chests"])
	_spawn_exit(markers["exit"])
	_hud = preload("res://src/ui/hud.gd").new()
	add_child(_hud)
	_hud.bind_player(_player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameSession.ui_open = false


func _spawn_player(at: Vector3, yaw: float = 0.0) -> void:
	_player = Player.new()
	add_child(_player)
	_player.global_position = at
	_player.rotation.y = yaw
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
		var chest := Interactable.new()
		chest.prompt = "Open chest"
		chest.consume_on_use = true
		var visual := DungeonKit.chest_visual()
		visual.position = Vector3(0, 0.0, 0)
		chest.add_child(visual)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.1, 1.0, 0.9)
		shape.shape = box
		chest.add_child(shape)
		add_child(chest)
		chest.global_position = pos
		chest.activated.connect(_on_chest_opened.bind(chest))


func _spawn_exit(at: Variant) -> void:
	if at == null:
		return
	_exit = Interactable.new()
	_exit.prompt = "Leave through the gate"
	_exit.locked = true
	var visual := DungeonKit.gate_visual()
	visual.position = Vector3(0, 0.0, 0)
	_exit.add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.6, 0.8)
	shape.shape = box
	_exit.add_child(shape)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.8)
	light.light_energy = 2.2
	light.omni_range = 5.0
	light.position = Vector3(0, 1.6, 0)
	_exit.add_child(light)
	add_child(_exit)
	_exit.global_position = at
	_exit.activated.connect(_on_exit_used)


func _on_monster_died(monster: Monster) -> void:
	_alive_monsters = maxi(0, _alive_monsters - 1)
	GameSession.run.living_monsters = _alive_monsters
	GameSession.record_kill(monster.def.id)
	if monster.def.drop_chance >= 1.0 or GameSession.randf() <= monster.def.drop_chance:
		var loot := GameSession.roll_table(monster.def.loot_table_id)
		var drop_at := monster.global_position + Vector3(0, 0.2, 0)
		call_deferred("_spawn_loot_drops", loot, drop_at)
	if monster.def.is_boss:
		GameSession.run.boss_defeated = true
		if _exit:
			_exit.locked = false
			GameSession.log_message.emit("The gate unlocks.", Color(0.55, 1.0, 0.8))


func _spawn_loot_drops(loot: Array, at: Vector3) -> void:
	for i in loot.size():
		var drop := LootDrop.new()
		add_child(drop)
		drop.setup(loot[i])
		drop.global_position = at + Vector3(0.12 * float(i), 0.0, 0.08 * float(i))


func _on_chest_opened(_by: Node, chest: Interactable) -> void:
	var table_id := &"chest_drops"
	if GameSession.run != null:
		var dungeon: DungeonTypeDef = ContentDB.get_dungeon(GameSession.run.dungeon_id)
		if dungeon != null and not String(dungeon.loot_table_id).is_empty():
			table_id = dungeon.loot_table_id
	var loot := GameSession.roll_table(table_id)
	var drop_at: Vector3 = chest.global_position + Vector3(0.0, 0.3, 0.4)
	call_deferred("_spawn_loot_drops", loot, drop_at)
	if is_instance_valid(chest):
		chest.queue_free()


func _on_exit_used(_by: Node) -> void:
	GameSession.end_run(true)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _on_player_died() -> void:
	GameSession.log_message.emit("You fall in the dark.", Color(1.0, 0.3, 0.25))
	await get_tree().create_timer(1.4).timeout
	GameSession.end_run(false)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
