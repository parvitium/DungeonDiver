class_name TestGameplay
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("gameplay")
	_strike_math(t)
	_spawn_spread(t)
	await _melee_reach(t)
	await _chest_prompt(t)
	_chest_stays_open(t)
	await _mob_separation(t)
	await _monster_windup_and_bolt(t)
	_projectile_enemy_mask(t)
	_vfx_pool(t)
	_death_overlay(t)
	_inventory_panel(t)
	await _interact_blocked_by_wall(t)
	await _wolf_los_and_capsule(t)
	_death_penalty(t)
	_restore()
	return t


static func _strike_math(t: DDTest) -> void:
	var origin := Vector3(0, 1.5, 0)
	var forward := Vector3(0, 0, -1)
	t.assert_true(
		StrikeQuery.in_cone(origin, forward, Vector3(0, 1.5, -1.5), 2.0, 100.0),
		"1.5m ahead in cone"
	)
	t.assert_false(
		StrikeQuery.in_cone(origin, forward, Vector3(0, 1.5, -4.0), 2.0, 100.0),
		"4m ahead out of range"
	)
	t.assert_false(
		StrikeQuery.in_cone(origin, forward, Vector3(0, 1.5, 1.5), 2.0, 100.0),
		"behind the swing"
	)
	t.assert_in_range(StrikeQuery.MELEE_RANGE, 1.8, 2.2, "player melee range")
	t.assert_in_range(StrikeQuery.MELEE_CONE_DEG, 90.0, 110.0, "player melee cone")


static func _spawn_spread(t: DDTest) -> void:
	var offsets := DungeonBuilder.monster_spawn_offsets(3)
	t.assert_eq(offsets.size(), 3, "three unique offsets")
	t.assert_gt(offsets[0].distance_to(offsets[1]), 1.6, "spawn pair 0-1 spread")
	t.assert_gt(offsets[1].distance_to(offsets[2]), 1.6, "spawn pair 1-2 spread")
	t.assert_gt(offsets[0].distance_to(offsets[2]), 1.6, "spawn pair 0-2 spread")


static func _frames(count: int = 2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for _i in count:
		await tree.physics_frame


static func _melee_reach(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := _world(tree)
	var player_script: GDScript = load("res://src/player/player.gd")
	var player: Node = player_script.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.call("_build_rig")
	player.global_position = Vector3(0, 0.05, 0)

	var near := _dummy_monster(world, player.global_position + Vector3(0, 0, -1.5))
	var far := _dummy_monster(world, player.global_position + Vector3(0, 0, -4.0))
	var behind := _dummy_monster(world, player.global_position + Vector3(0, 0, 1.5))
	var wall := _wall(world, Vector3(0, 1.0, -2.35))
	var blocked := _dummy_monster(world, player.global_position + Vector3(0, 0, -2.8))

	await _frames(4)
	_swing(player)
	t.assert_gt(float(near.hits), 0.0, "hits enemy at 1.5m")
	t.assert_eq(far.hits, 0, "does not hit at 4m")
	t.assert_eq(behind.hits, 0, "does not hit behind")
	t.assert_eq(blocked.hits, 0, "does not hit through walls")
	world.free()


static func _chest_prompt(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := _world(tree)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var player_script: GDScript = load("res://src/player/player.gd")
	var player: Node = player_script.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.call("_build_rig")
	player.global_position = Vector3(0, 0.05, 0)
	var chest := LootChest.new()
	world.add_child(chest)
	chest.global_position = Vector3(0, 0.0, -1.5)
	player.call("aim_camera_at", chest.global_position + Vector3(0, 0.4, 0))
	await _frames(4)
	player.call("_update_prompt")
	var prompt := str(player.call("focus_prompt"))
	t.assert_true(prompt.contains("Open chest") or prompt.contains("E —"), "dead-center chest prompt at 1.5m")
	world.free()


static func _chest_stays_open(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	session.start_run(&"crypt", 1, 7)
	var tree := Engine.get_main_loop() as SceneTree
	var world := _world(tree)
	var chest := LootChest.new()
	chest.chest_key = "demo_chest"
	world.add_child(chest)
	t.assert_true(chest.try_use(null), "chest opens")
	t.assert_true(chest.used, "chest marked used")
	t.assert_eq(chest.collision_layer, 0, "opened chest drops interact")
	t.assert_true(session.run.is_chest_open("demo_chest"), "opened chest persisted on run")
	var lid: Node3D = chest.get_node_or_null("LidPivot")
	t.assert_true(lid != null, "lid pivot exists")
	session.end_run(false)
	world.free()


static func _mob_separation(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := _world(tree)
	_floor(world)
	var monster_script: GDScript = load("res://src/monster/monster.gd")
	var db := DDTest.autoload("ContentDB")
	var skel: MonsterDef = db.get_monster(&"skeleton")
	var a: Node = monster_script.new()
	var b: Node = monster_script.new()
	world.add_child(a)
	world.add_child(b)
	a.set_physics_process(false)
	b.set_physics_process(false)
	a.call("setup", skel, 1)
	b.call("setup", skel, 1)
	a.global_position = Vector3(0.05, 0.05, 0)
	b.global_position = Vector3(-0.05, 0.05, 0)
	a.set("patrol_target", Vector3(4, 0, 0))
	b.set("patrol_target", Vector3(-4, 0, 0))
	for _i in 24:
		a.call("_physics_process", 0.016)
		b.call("_physics_process", 0.016)
	var dist: float = a.global_position.distance_to(b.global_position)
	t.assert_ge(dist, 0.85, "mobs separate to min distance")
	world.free()


static func _monster_windup_and_bolt(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := _world(tree)
	_floor(world)
	var dummy := _dummy_player(world, Vector3(0, 0.05, -1.4))
	var monster_script: GDScript = load("res://src/monster/monster.gd")
	var db := DDTest.autoload("ContentDB")
	var skel: MonsterDef = db.get_monster(&"skeleton")
	var mob: Node = monster_script.new()
	world.add_child(mob)
	mob.set_physics_process(false)
	mob.call("setup", skel, 1)
	mob.global_position = Vector3(0, 0.05, 0)
	mob.call("_physics_process", 0.016)
	t.assert_eq(int(mob.get("state")), 2, "melee enters windup")
	t.assert_eq(dummy.hits, 0, "windup does not damage")
	for _i in 40:
		mob.call("_physics_process", 0.02)
	t.assert_gt(float(dummy.hits), 0.0, "melee lands after windup at 1.4m")

	var far := _dummy_player(world, Vector3(0, 0.05, -4.0))
	far.remove_from_group("player")
	dummy.add_to_group("player")
	var wraith_def: MonsterDef = db.get_monster(&"wraith")
	var caster: Node = monster_script.new()
	world.add_child(caster)
	caster.set_physics_process(false)
	caster.call("setup", wraith_def, 1)
	caster.global_position = Vector3(8, 0.05, 8)
	await _frames()
	caster.call("_begin_windup")
	t.assert_true(caster.get_node_or_null("OmniLight3D") != null or caster.get("windup_timer") > 0.0, "caster winds up")
	var hp_before := far.health
	caster.call("_land_strike")
	var bolts := 0
	for child in world.get_children():
		if child is Projectile:
			bolts += 1
			t.assert_eq(child.collision_mask, DD.PLAYER_LAYER | DD.WORLD_LAYER, "enemy bolt hits player+world")
	t.assert_gt(float(bolts), 0.0, "wraith fires a visible projectile")
	t.assert_eq(far.health, hp_before, "bolt does not hitscan on spawn")
	world.free()


static func _projectile_enemy_mask(t: DDTest) -> void:
	var bolt := Projectile.new()
	bolt.setup(Vector3(0, 1, 0), Vector3(0, 0, -1), 8.0, 9.0, false, Color(0.5, 0.8, 1.0))
	t.assert_eq(bolt.collision_mask, DD.PLAYER_LAYER | DD.WORLD_LAYER, "enemy mask set in setup")
	t.assert_true(bolt.get_node_or_null("BoltVisual") != null, "bolt has a visible core")
	bolt.free()


static func _vfx_pool(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var vfx := CombatVfx.new()
	tree.root.add_child(vfx)
	t.assert_eq(CombatVfx.material_for(&"skeleton"), &"bone", "skeleton bone vfx")
	t.assert_eq(CombatVfx.material_for(&"cave_wolf"), &"flesh", "wolf flesh vfx")
	t.assert_eq(CombatVfx.material_for(&"wraith"), &"magic", "wraith magic vfx")
	t.assert_eq(CombatVfx.projectile_kind_for(&"lich"), &"ice", "lich ice shard")
	vfx.hit(Vector3(0, 1, 0), Vector3(0, 0, -1), &"spark")
	vfx.hit(Vector3(0, 1, 0), Vector3(0, 0, -1), &"spark")
	t.assert_true(vfx.get_child_count() > 0, "vfx spawned pooled particles")
	var fire := Projectile.new()
	fire.setup(Vector3.ZERO, Vector3(0, 0, -1), 8.0, 10.0, true, Color.ORANGE, &"fireball")
	t.assert_true(fire.get_node_or_null("BoltVisual") != null, "fireball visual")
	fire.free()
	var ice := Projectile.new()
	ice.setup(Vector3.ZERO, Vector3(0, 0, -1), 8.0, 10.0, false, Color.CYAN, &"ice")
	t.assert_true(ice.get_node_or_null("BoltVisual") != null, "ice shard visual")
	ice.free()
	var arrow := Projectile.new()
	arrow.setup(Vector3.ZERO, Vector3(0, 0, -1), 8.0, 14.0, true, Color.WHITE, &"arrow")
	t.assert_true(arrow.get_node_or_null("BoltVisual") != null, "arrow visual")
	arrow.free()
	vfx.free()


static func _inventory_panel(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	session.reset_profile(false)
	for i in 22:
		var it := ItemInstance.new()
		it.instance_id = "fill_%d" % i
		it.def_id = &"rusty_sword"
		it.display_name = "Long Relic Name Number %d" % i
		it.slot = (i % 6) as DD.EquipSlot
		it.rarity = (i % 5) as DD.Rarity
		it.stats = StatBlock.new(float(i), 1.0, 2.0, 0, 0)
		session.profile.inventory.add_item(it)
	session.profile.inventory.equip("fill_0")
	var tree := Engine.get_main_loop() as SceneTree
	var panel_script: GDScript = load("res://src/ui/inventory_panel.gd")
	var panel: Control = panel_script.new()
	tree.root.add_child(panel)
	panel.call("refresh")
	t.assert_true(panel.get_node_or_null("PackPanel") != null or _find_name(panel, "BagScroll") != null, "pack panel built")
	var scroll := _find_name(panel, "BagScroll")
	t.assert_true(scroll is ScrollContainer, "bag is a ScrollContainer")
	var list := _find_name(panel, "BagList")
	t.assert_true(list != null, "bag list exists")
	if list:
		t.assert_ge(float(list.get_child_count()), 20.0, "long inventory listed")
	var detail := _find_name(panel, "DetailCard")
	t.assert_true(detail != null, "detail card exists")
	panel.free()
	session.reset_profile(false)


static func _find_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_name(child, node_name)
		if found:
			return found
	return null


static func _death_overlay(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var overlay_script: GDScript = load("res://src/ui/death_overlay.gd")
	var overlay: CanvasLayer = overlay_script.new()
	tree.root.add_child(overlay)
	var retried := {"n": 0}
	var menued := {"n": 0}
	overlay.retry_pressed.connect(func() -> void: retried["n"] += 1)
	overlay.menu_pressed.connect(func() -> void: menued["n"] += 1)
	overlay.call("present", {"dungeon": "Forgotten Crypt", "depth": 2, "kills": 5, "lost": 3}, true)
	t.assert_true(bool(overlay.call("is_showing")), "death overlay shows")
	t.assert_true(str(overlay.call("title_text")).contains("You Died"), "You Died title")
	t.assert_true(str(overlay.call("stats_text")).contains("Depth 2"), "depth on death stats")
	t.assert_true(str(overlay.call("stats_text")).contains("5 slain"), "kills on death stats")
	t.assert_true(str(overlay.call("lost_text")).contains("Lost 3 items found this run"), "lost loot line")
	t.assert_false(MouseCapture.is_captured(), "death overlay releases mouse")
	overlay.call("press_retry")
	t.assert_eq(retried["n"], 1, "Retry emits")
	overlay.call("present", {"dungeon": "Forgotten Crypt", "depth": 1, "kills": 0}, true)
	overlay.call("press_menu")
	t.assert_eq(menued["n"], 1, "Main Menu emits")
	overlay.free()
	tree.paused = false
	DDTest.autoload("GameSession").ui_open = false
	MouseCapture.apply(MouseCapture.Context.HUB)


static func _swing(player: Node) -> void:
	var cmd := PlayerCommand.new()
	cmd.melee = true
	player.call("apply_command", cmd, 0.016)
	for _i in 16:
		player.call("apply_command", PlayerCommand.new(), 0.016)


static func _world(tree: SceneTree) -> Node3D:
	var world := Node3D.new()
	tree.root.add_child(world)
	world.force_update_transform()
	return world


static func _floor(world: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = DD.WORLD_LAYER
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.4, 40)
	col.shape = box
	body.add_child(col)
	world.add_child(body)
	body.global_position = Vector3(0, -0.2, 0)


static func _wall(world: Node3D, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = DD.WORLD_LAYER
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.4)
	col.shape = box
	body.add_child(col)
	world.add_child(body)
	body.global_position = at
	return body


static func _dummy_monster(world: Node3D, at: Vector3) -> _HitDummy:
	var dummy := _HitDummy.new()
	dummy.collision_layer = DD.MONSTER_LAYER
	dummy.collision_mask = 0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	dummy.add_child(col)
	world.add_child(dummy)
	dummy.global_position = at
	return dummy


static func _dummy_player(world: Node3D, at: Vector3) -> _HitDummy:
	var dummy := _HitDummy.new()
	dummy.collision_layer = DD.PLAYER_LAYER
	dummy.collision_mask = DD.WORLD_LAYER
	dummy.add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	dummy.add_child(col)
	world.add_child(dummy)
	dummy.global_position = at
	return dummy


static func _interact_blocked_by_wall(t: DDTest) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := _world(tree)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var player_script: GDScript = load("res://src/player/player.gd")
	var player: Node = player_script.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.call("_build_rig")
	player.global_position = Vector3(0, 0.05, 0)
	var chest := LootChest.new()
	world.add_child(chest)
	chest.global_position = Vector3(0, 0.0, -1.8)
	_wall(world, Vector3(0, 1.0, -0.9))
	player.call("aim_camera_at", chest.global_position + Vector3(0, 0.4, 0))
	await _frames()
	player.call("_update_prompt")
	t.assert_eq(str(player.call("focus_prompt")), "", "wall blocks chest interact")
	world.free()


static func _wolf_los_and_capsule(t: DDTest) -> void:
	var cfg := MonsterVisuals.config_for(&"cave_wolf")
	t.assert_in_range(MonsterVisuals.capsule_radius_of(cfg), 0.3, 0.55, "wolf capsule radius")
	t.assert_in_range(MonsterVisuals.capsule_height_of(cfg), 0.7, 1.2, "wolf capsule height")
	t.assert_true(
		MonsterVisuals.capsule_height_of(cfg) < MonsterVisuals.CAPSULE_HEIGHT,
		"wolf shorter than humanoid capsule"
	)

	var tree := Engine.get_main_loop() as SceneTree
	var world := _world(tree)
	_floor(world)
	var dummy := _dummy_player(world, Vector3(0, 0.05, -3.0))
	_wall(world, Vector3(0, 1.0, -1.2))
	var monster_script: GDScript = load("res://src/monster/monster.gd")
	var db := DDTest.autoload("ContentDB")
	var wolf_def: MonsterDef = db.get_monster(&"cave_wolf")
	var wolf: Node = monster_script.new()
	world.add_child(wolf)
	wolf.set_physics_process(false)
	wolf.call("setup", wolf_def, 1)
	wolf.global_position = Vector3(0, 0.05, 0)
	var hurt: CollisionShape3D = wolf.get_node("Hurtbox")
	var shape := hurt.shape as CapsuleShape3D
	t.assert_in_range(shape.height, 0.7, 1.2, "wolf hurtbox height")
	await _frames()
	wolf.call("_physics_process", 0.016)
	t.assert_eq(int(wolf.get("state")), 0, "wolf does not chase through a wall")
	dummy.global_position = Vector3(0, 0.05, -1.4)
	world.free()


static func _death_penalty(t: DDTest) -> void:
	var session := DDTest.autoload("GameSession")
	session.reset_profile(false)
	session.start_run(&"crypt", 1, 11)
	var loot := ItemInstance.new()
	loot.instance_id = "run_loot"
	loot.def_id = &"rusty_sword"
	loot.display_name = "Run Sword"
	loot.slot = DD.EquipSlot.WEAPON
	loot.rarity = DD.Rarity.COMMON
	loot.stats = StatBlock.new(1, 0, 0, 0, 0)
	var loot_list: Array[ItemInstance] = []
	loot_list.append(loot)
	session.give_loot(loot_list)
	t.assert_true(session.profile.inventory.find("run_loot") != null, "run loot in bag")
	var lost: int = session.apply_death_penalty()
	t.assert_eq(lost, 1, "lost the run-found item")
	t.assert_true(session.profile.inventory.find("run_loot") == null, "run loot stripped")
	session.end_run(false)


static func _restore() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.paused = false
	var session := DDTest.autoload("GameSession")
	session.ui_open = false
	MouseCapture.apply(MouseCapture.Context.HUB)


class _HitDummy extends CharacterBody3D:
	var hits: int = 0
	var health: float = 100.0

	func receive_hit(raw_damage: float, _from: Vector3, _already_mitigated: bool) -> void:
		hits += 1
		health -= raw_damage
