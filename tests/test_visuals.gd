class_name TestVisuals
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("visuals")
	t.assert_eq(MonsterVisuals.CAPSULE_RADIUS, 0.4, "hitbox radius unchanged")
	t.assert_eq(MonsterVisuals.CAPSULE_HEIGHT, 1.6, "hitbox height unchanged")
	for id in ["skeleton", "cave_wolf", "wraith", "lich", "cave_troll"]:
		var cfg: Dictionary = MonsterVisuals.config_for(StringName(id))
		t.assert_true(not cfg.is_empty(), "%s visual config" % id)
		t.assert_true(ResourceLoader.exists(String(cfg["scene"])), "%s glb present" % id)
		var def: MonsterDef = null
		for m in Catalog.all_monsters():
			if String(m.id) == id:
				def = m
				break
		var probe := Node3D.new()
		if def:
			MonsterVisuals.attach(probe, def)
			var vis := probe.get_node_or_null("BodyVisual") as Node3D
			if vis:
				var aabb := Greybox.visual_aabb(vis)
				t.assert_true(aabb.size.y > 0.8 and aabb.size.y < 2.6, "%s fitted height" % id)
		probe.free()

	for folder in [
		"res://assets/textures/castle_brick_01/diff.jpg",
		"res://assets/textures/cobblestone_floor_13/diff.jpg",
		"res://assets/textures/rock_wall_13/diff.jpg",
		"res://assets/textures/rock_face/diff.jpg",
		"res://assets/textures/weathered_brown_planks/diff.jpg",
		"res://assets/models/props/Torch_wall.glb",
		"res://assets/models/props/Crate.glb",
		"res://assets/models/props/Barrel.glb",
	]:
		t.assert_true(ResourceLoader.exists(folder), folder)

	var crypt: DungeonTypeDef = Catalog.all_dungeons()[0]
	var wall := DungeonMaterials.wall_mat(crypt)
	var floor := DungeonMaterials.floor_mat(crypt)
	t.assert_true(wall != null and wall.albedo_texture != null, "crypt wall albedo")
	t.assert_true(floor != null and floor.albedo_texture != null, "crypt floor albedo")
	t.assert_true(wall.uv1_triplanar, "triplanar walls")
	t.assert_true(DungeonMaterials.wall_mat(crypt) == wall, "materials are shared")

	var blueprint := DungeonGenerator.generate(crypt, 1, 2026)
	var world := Node3D.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(world)
	var markers: Dictionary = DungeonBuilder.new().build(world, blueprint, crypt, false)
	t.assert_true(markers.has("player"), "player marker")
	var torch_count := _count_type(world, "OmniLight3D")
	t.assert_ge(float(torch_count), 2.0, "torches spawned")
	t.assert_true(_has_type(world, "OmniLight3D"), "torch omni lights")
	t.assert_true(_has_type(world, "SpotLight3D"), "shadow spotlight")
	var env := _find_env(world)
	t.assert_true(env != null, "world environment")
	if env:
		t.assert_true(env.ssao_enabled, "SSAO on")
		t.assert_true(env.fog_enabled, "fog on")
		t.assert_true(env.volumetric_fog_enabled, "volumetric fog on")

	# Runtime load: class_name Monster references GameSession, which is not
	# bound yet when `-s` compiles preloaded suites.
	var monster_script: GDScript = load("res://src/monster/monster.gd")
	var mob: Node = monster_script.new()
	world.add_child(mob)
	mob.set_physics_process(false)
	var skel: MonsterDef = null
	for m in Catalog.all_monsters():
		if String(m.id) == "skeleton":
			skel = m
			break
	t.assert_true(skel != null, "skeleton def")
	mob.call("setup", skel, 1)
	var hurt := mob.get_node("Hurtbox") as CollisionShape3D
	t.assert_true(hurt != null, "hurtbox node")
	var cap := hurt.shape as CapsuleShape3D
	t.assert_true(cap != null, "capsule shape")
	if cap:
		t.assert_true(is_equal_approx(cap.radius, 0.4), "live radius")
		t.assert_true(is_equal_approx(cap.height, 1.6), "live height")
	t.assert_true(mob.get_node_or_null("BodyVisual") != null, "body visual socket")
	var vis := mob.get_node_or_null("BodyVisual") as Node3D
	if vis:
		var aabb := Greybox.visual_aabb(vis)
		t.assert_true(aabb.size.y > 1.2 and aabb.size.y < 2.4, "fitted visual height")
	_assert_locomotion_loops(t, mob)
	mob.free()

	# Hub construction must still work; this pass does not restyle the menu.
	var hub_script := FileAccess.get_file_as_string("res://src/world/hub.gd")
	t.assert_true(hub_script.contains("DungeonDiver"), "hub title copy intact")
	t.assert_true(hub_script.contains("Enter at depth"), "hub enter copy intact")
	t.assert_true(hub_script.contains("Depth %d"), "labelled equal-width depth buttons")
	t.assert_true(hub_script.contains("DepthRow"), "depth row named")

	world.free()
	return t


static func _assert_locomotion_loops(t: DDTest, mob: Node) -> void:
	var anim := _find_anim(mob)
	t.assert_true(anim != null, "animation player")
	if anim == null:
		return
	var info := {"anim": anim, "config": MonsterVisuals.config_for(&"skeleton")}
	t.assert_true(MonsterVisuals.play(info, "idle", true), "play idle")
	anim.advance(3.0)
	t.assert_true(anim.is_playing(), "idle still playing after 3s")
	var idle_clip := anim.current_animation
	t.assert_true(anim.has_animation(idle_clip), "idle clip exists")
	if anim.has_animation(idle_clip):
		t.assert_eq(
			anim.get_animation(idle_clip).loop_mode,
			Animation.LOOP_LINEAR,
			"idle loop_mode"
		)
	t.assert_true(MonsterVisuals.play(info, "walk", true), "play walk")
	anim.advance(3.0)
	t.assert_true(anim.is_playing(), "walk still playing after 3s")
	t.assert_true(MonsterVisuals.play(info, "attack", false), "play attack")
	var atk := anim.current_animation
	if anim.has_animation(atk):
		t.assert_eq(
			anim.get_animation(atk).loop_mode,
			Animation.LOOP_NONE,
			"attack plays once"
		)


static func _find_anim(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_anim(child)
		if found:
			return found
	return null


static func _count_type(root: Node, type_name: String) -> int:
	var n := 1 if root.get_class() == type_name else 0
	for child in root.get_children():
		n += _count_type(child, type_name)
	return n


static func _has_type(root: Node, type_name: String) -> bool:
	if root.get_class() == type_name:
		return true
	for child in root.get_children():
		if _has_type(child, type_name):
			return true
	return false


static func _find_env(root: Node) -> Environment:
	if root is WorldEnvironment:
		return (root as WorldEnvironment).environment
	for child in root.get_children():
		var found := _find_env(child)
		if found:
			return found
	return null
