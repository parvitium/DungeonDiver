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
	t.assert_true(floor_mat.heightmap_enabled, "cavern floor height/grout")
	t.assert_true(floor_mat.heightmap_texture != null, "cavern floor height texture")
	var crypt_floor := PBRLibrary.floor_mat(&"crypt")
	t.assert_true(crypt_floor.heightmap_enabled, "crypt floor height/grout")
	t.assert_true(PBRLibrary.moss().albedo_texture != null or PBRLibrary.moss().albedo_color.g > 0.3, "moss material")
	t.assert_true(PBRLibrary.tattered_cloth(Color(0.3, 0.2, 0.2)).cull_mode == BaseMaterial3D.CULL_DISABLED, "tattered cloth two-sided")
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
	t.assert_true(PBRLibrary.cloth(Color(0.2, 0.1, 0.25)).albedo_texture != null, "cloth has albedo map")
	t.assert_true(PBRLibrary.hide().albedo_texture != null, "hide has albedo map")
	t.assert_true(PBRLibrary.skin().albedo_texture != null, "skin has albedo map")
	t.assert_true(PBRLibrary.fur().albedo_texture != null, "fur has albedo map")
	t.assert_true(PBRLibrary.fur().normal_enabled, "fur has normal detail")
	t.assert_true(PBRLibrary.wet(&"crypt").roughness < 0.35, "wet stone is glossy")

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
		t.assert_true(mob.get_node_or_null("Crown") == null, "%s has no floating crown cube" % monster_def.id)
		var vis := mob.get_node_or_null("BodyVisual") as Node3D
		t.assert_true(vis != null, "%s BodyVisual" % monster_def.id)
		t.assert_false(_has_huge_scale(vis), "%s visual scale is sane" % monster_def.id)
		var aabb := _world_aabb(vis)
		t.assert_true(absf(aabb.position.y) <= 0.12, "%s visual AABB bottom near floor (y=%s)" % [monster_def.id, snapped(aabb.position.y, 0.001)])
		t.assert_true(aabb.size.y >= 0.45, "%s visual height >= 0.45 (h=%s)" % [monster_def.id, aabb.size.y])
		t.assert_true(aabb.size.y <= 3.2, "%s visual height <= 3.2 (h=%s)" % [monster_def.id, aabb.size.y])
		if String(monster_def.id) == "cave_wolf":
			t.assert_true(aabb.size.y < 2.5, "wolf height under 2.5m")
			t.assert_true(aabb.position.y + aabb.size.y < 2.0, "wolf not parked in the sky")
			t.assert_true(absf(vis.position.y) < 0.35, "wolf BodyVisual not lifted")
			t.assert_true(_has_name_prefix(mob, "Fur") or _has_name_prefix(mob, "Wolf"), "wolf uses fur-named mesh")
		if String(monster_def.id) == "cave_troll":
			t.assert_true(_has_name_prefix(mob, "Skin"), "troll has skin parts")
			t.assert_true(_has_name_prefix(mob, "Loin"), "troll has loincloth")
			t.assert_true(_has_name_prefix(mob, "Skin_foot") or _has_name_prefix(mob, "Skin_toe"), "troll feet have toes")
			t.assert_true(_has_name_prefix(mob, "Club"), "troll holds a club")
			t.assert_false(_has_name_prefix(mob, "Stone"), "troll has no yellow stone back")
			t.assert_true(_has_name_prefix(mob, "Skin_snout") or _has_name_prefix(mob, "Skin_head"), "troll has a shaped head/snout")
			var face_z := _face_marker_z(vis)
			t.assert_true(face_z < 0.0, "troll snout/eyes sit on local -Z (look_at forward) z=%s" % snapped(face_z, 0.001))
		if String(monster_def.id) == "skeleton":
			t.assert_true(_has_name_prefix(mob, "Sword"), "skeleton holds a sword")
			t.assert_true(_has_name_prefix(mob, "Armor_pauldron"), "skeleton has pauldrons")
		if String(monster_def.id) == "lich":
			t.assert_true(_has_name_prefix(mob, "Staff") or _has_name_prefix(mob, "Glow"), "lich has staff/orb")
			t.assert_true(_has_name_prefix(mob, "Robe"), "lich has draped robe")
			t.assert_true(_has_name_prefix(mob, "Cloth"), "lich has layered tattered cloth")
		if String(monster_def.id) == "wraith":
			t.assert_true(_has_name_prefix(mob, "Hood") or _has_name_prefix(mob, "Robe"), "wraith has cloth")
			t.assert_true(_has_name_prefix(mob, "Cloth"), "wraith has layered tattered cloth")
		if String(monster_def.id) == "cave_wolf":
			t.assert_true(_has_name_prefix(mob, "Fur_shell") or _has_name_prefix(mob, "Fur_card"), "wolf has fur shell or cards")
		_assert_death_pose(t, mob, String(monster_def.id))
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
	t.assert_true(_has_named(world, "Flagstone") or _has_named(world, "Vault") or _has_named(world, "Niche"), "dungeon architecture present")
	t.assert_true(_has_named(world, "Moss") or _has_named(world, "Damp") or _has_named(world, "Grime"), "corner moss/grime/damp")
	t.assert_true(_has_named(world, "PillarBase") or _has_named(world, "PillarCap") or _has_named(world, "pillar"), "pillars with base/capital")
	t.assert_true(_has_named(world, "WallStone") or _has_named(world, "WallPanel"), "irregular stone walls")
	var start := blueprint.start_room()
	var origin := start.world_origin()
	var spawn: Vector3 = markers["player"]
	t.assert_true(spawn.distance_to(origin) > 1.4, "crypt spawn is not room-center")
	var yaw := float(markers["player_yaw"])
	var look := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var inward: Vector3 = origin - spawn
	inward.y = 0.0
	t.assert_true(look.dot(inward.normalized()) > 0.25, "crypt spawn faces into the room")
	world.free()
	return t


static func _assert_death_pose(t: DDTest, mob: Node, monster_id: String) -> void:
	var anim := AssetLibrary.first_animation_player(mob)
	t.assert_true(anim != null, "%s death anim player" % monster_id)
	if anim == null:
		return
	var clip := AssetLibrary.resolve_clip(anim, "death")
	t.assert_true(not clip.is_empty(), "%s death clip" % monster_id)
	if clip.is_empty():
		return
	anim.play(clip)
	var animation := anim.get_animation(clip)
	var length := animation.length if animation else 1.0
	anim.seek(length, true)
	anim.advance(0.0)
	var skel := _find_skeleton(mob)
	if skel:
		skel.force_update_all_bone_transforms()
	var vis := mob.get_node_or_null("BodyVisual") as Node3D
	t.assert_true(vis != null, "%s death visual" % monster_id)
	var hips_y := _bone_world_y(skel, vis, ["Hips", "hips", "Root", "root", "Spine", "spine", "Body"])
	if hips_y >= 0.0:
		t.assert_true(hips_y >= 0.06 and hips_y <= 0.48, "%s death hips grounded y=%s" % [monster_id, snapped(hips_y, 0.001)])
	var head_y := _bone_world_y(skel, vis, ["Head", "head"])
	if head_y >= 0.0 and hips_y >= 0.0:
		t.assert_true(absf(head_y - hips_y) < 0.9, "%s death head near hips (upright-oriented, not inverted)" % monster_id)
		t.assert_true(head_y < 0.95, "%s death head not hanging in air y=%s" % [monster_id, snapped(head_y, 0.001)])
	var aabb := _world_aabb(vis)
	# Skinned get_aabb is bind-pose; still fail loudly if the whole visual is sky-high.
	if aabb.size.y > 0.2:
		t.assert_true(aabb.position.y < 0.55, "%s death AABB not inverted mid-air y0=%s" % [monster_id, snapped(aabb.position.y, 0.001)])


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


static func _bone_world_y(skel: Skeleton3D, vis: Node3D, names: PackedStringArray) -> float:
	if skel == null:
		return -1.0
	for n in names:
		var idx := skel.find_bone(n)
		if idx < 0:
			continue
		var local := skel.get_bone_global_pose(idx).origin
		if vis:
			return (_relative_xform(vis, skel) * local).y
		return local.y
	return -1.0


static func _face_marker_z(root: Node) -> float:
	var total := 0.0
	var count := 0
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		var n := String(node.name).to_lower()
		if node is MeshInstance3D and (n.contains("eye") or n.contains("snout") or n.contains("tusk") or n.begins_with("hood")):
			var mi := node as MeshInstance3D
			var xf := _relative_xform(root, mi)
			total += (xf * mi.get_aabb().get_center()).z
			count += 1
		for child in node.get_children():
			nodes.append(child)
	if count == 0:
		return 0.0
	return total / float(count)


static func _has_name_prefix(node: Node, prefix: String) -> bool:
	if String(node.name).begins_with(prefix):
		return true
	for child in node.get_children():
		if _has_name_prefix(child, prefix):
			return true
	return false


static func _has_named(node: Node, name: String) -> bool:
	if String(node.name) == name:
		return true
	for child in node.get_children():
		if _has_named(child, name):
			return true
	return false


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


static func _has_huge_scale(node: Node) -> bool:
	if (node is MeshInstance3D or node is Skeleton3D) and (node as Node3D).scale.x > 2.5:
		return true
	for child in node.get_children():
		if _has_huge_scale(child):
			return true
	return false


static func _world_aabb(root: Node3D) -> AABB:
	var local := _local_aabb(root, root)
	if local.size == Vector3.ZERO:
		return AABB()
	# Use the visual's local transform so this works before a process frame
	# (Skeleton3D mesh globals can still be identity in `godot -s` tests).
	return root.transform * local


static func _local_aabb(root: Node, node: Node) -> AABB:
	var points: Array[Vector3] = []
	_collect_local_points(root, node, points)
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for p in points:
		result = result.expand(p)
	return result


static func _collect_local_points(root: Node, node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var xf := _relative_xform(root, mi)
		var local := mi.get_aabb()
		for i in 8:
			points.append(xf * local.get_endpoint(i))
	for child in node.get_children():
		_collect_local_points(root, child, points)


static func _relative_xform(root: Node, node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
