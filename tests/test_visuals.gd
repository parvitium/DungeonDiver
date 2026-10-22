class_name TestVisuals
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("visuals")
	var box := MeshFactory.box(Vector3(2, 1, 3), 1.0)
	t.assert_true(box.get_surface_count() >= 1, "uv box has surface")
	var arrays := box.surface_get_arrays(0)
	t.assert_true(arrays[Mesh.ARRAY_TEX_UV] != null, "box UVs")
	t.assert_gt(float((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()), 8.0, "unique face verts")

	var wall := PBRLibrary.wall(&"crypt")
	t.assert_true(wall != null, "crypt wall material")
	t.assert_true(wall.albedo_texture != null, "crypt wall albedo")
	t.assert_true(wall.normal_enabled, "crypt wall normal")
	t.assert_true(wall.normal_texture != null, "crypt wall normal map")
	t.assert_true(wall.roughness_texture != null, "crypt wall roughness")
	t.assert_eq(wall.texture_filter, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "aniso mips")
	t.assert_true(wall.uv1_scale.x <= 0.75, "wall tile at least ~1.3m")
	t.assert_true(wall.uv1_scale.x >= 0.40, "wall tile at most ~2.5m")
	var floor_mat := PBRLibrary.floor_mat(&"cavern")
	t.assert_true(floor_mat.albedo_texture != null, "cavern floor albedo")
	t.assert_true(floor_mat.normal_enabled, "cavern floor normal")
	t.assert_true(PBRLibrary.wood().albedo_texture != null, "wood albedo")
	t.assert_true(PBRLibrary.metal().metallic > 0.4, "metal reads metal")
	var bevel := MeshFactory.beveled_box(Vector3(2, 1, 3), 0.04, 1.0)
	t.assert_true(bevel.get_surface_count() >= 1, "beveled box")
	t.assert_gt(float((bevel.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()), 24.0, "bevel adds verts")

	t.assert_true(ResourceLoader.exists("res://assets/meshes/monsters/skeleton.glb"), "skeleton glb")
	t.assert_true(ResourceLoader.exists("res://assets/meshes/monsters/cave_wolf.glb"), "wolf glb")
	t.assert_true(ResourceLoader.exists("res://assets/meshes/monsters/wraith.glb"), "wraith glb")
	t.assert_true(ResourceLoader.exists("res://assets/meshes/monsters/lich.glb"), "lich glb")
	t.assert_true(ResourceLoader.exists("res://assets/meshes/monsters/cave_troll.glb"), "troll glb")
	t.assert_true(ResourceLoader.exists("res://assets/meshes/weapons/sword.glb"), "sword glb")
	t.assert_true(ResourceLoader.exists("res://assets/meshes/props/torch.glb"), "torch glb")

	var bone := PBRLibrary.bone()
	t.assert_true(bone.albedo_color.r >= 0.85, "bone is light")
	t.assert_true(absf(bone.albedo_color.r - bone.albedo_color.b) < 0.18, "bone is not sandy orange")
	t.assert_true(bone.albedo_texture != null, "bone has albedo map")

	# Runtime load so autoload names exist (`-s` compiles class_name deps before autoloads).
	var monster_script: GDScript = load("res://src/monster/monster.gd")
	var tree := Engine.get_main_loop() as SceneTree
	for monster_def in Catalog.all_monsters():
		var mob: Node = monster_script.new()
		tree.root.add_child(mob)
		mob.call("setup", monster_def, 1)
		t.assert_true(mob.get_node_or_null("HealthBar") != null, "%s health bar exists" % monster_def.id)
		t.assert_false((mob.get_node("HealthBar") as Node3D).visible, "%s health bar hidden until hit" % monster_def.id)
		t.assert_false(_has_label3d(mob), "%s has no floating name label" % monster_def.id)
		var anim := AssetLibrary.first_animation_player(mob)
		t.assert_true(anim != null, "%s has AnimationPlayer" % monster_def.id)
		for clip in ["idle", "walk", "attack", "hit", "death"]:
			t.assert_true(not AssetLibrary.resolve_clip(anim, clip).is_empty(), "%s clip %s" % [monster_def.id, clip])
		if String(monster_def.id) == "skeleton":
			mob.call("receive_hit", 1.0, Vector3.ZERO, true)
			t.assert_true((mob.get_node("HealthBar") as Node3D).visible, "health bar shows on hit")
		mob.free()

	var def: DungeonTypeDef = Catalog.all_dungeons()[0]
	var blueprint := DungeonGenerator.generate(def, 1, 77)
	var world := Node3D.new()
	var markers: Dictionary = DungeonBuilder.new().build(world, blueprint, def, false)
	t.assert_true(markers.has("player"), "player marker after kit build")
	t.assert_gt(float(world.get_child_count()), 8.0, "kit spawned nodes")
	t.assert_true(_has_socket(world), "asset sockets remain")
	world.free()
	return t


static func _has_socket(node: Node) -> bool:
	if node.has_meta("asset_socket"):
		return true
	for child in node.get_children():
		if _has_socket(child):
			return true
	return false


static func _has_label3d(node: Node) -> bool:
	if node is Label3D:
		return true
	for child in node.get_children():
		if _has_label3d(child):
			return true
	return false
