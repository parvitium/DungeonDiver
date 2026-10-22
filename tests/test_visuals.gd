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
	t.assert_true(ResourceLoader.exists("res://assets/meshes/weapons/sword.glb"), "sword glb")
	t.assert_true(ResourceLoader.exists("res://assets/meshes/props/torch.glb"), "torch glb")

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
