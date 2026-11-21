class_name DungeonMaterials
extends RefCounted
## Shared PBR materials for dungeon geometry. Textures are CC0 (see ASSET_LICENSES.md).

const TEX_BRICK := "res://assets/textures/castle_brick_01/"
const TEX_FLOOR := "res://assets/textures/cobblestone_floor_13/"
const TEX_ROCK_WALL := "res://assets/textures/rock_wall_13/"
const TEX_ROCK_FACE := "res://assets/textures/rock_face/"
const TEX_WOOD := "res://assets/textures/weathered_brown_planks/"

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func floor_mat(def: DungeonTypeDef) -> StandardMaterial3D:
	var key := "floor_%s" % String(def.id)
	if String(def.id) == "cavern":
		return _pbr(key, TEX_ROCK_FACE, def.floor_color.lerp(Color.WHITE, 0.55), 0.22)
	return _pbr(key, TEX_FLOOR, def.floor_color.lerp(Color.WHITE, 0.62), 0.28)


static func wall_mat(def: DungeonTypeDef) -> StandardMaterial3D:
	var key := "wall_%s" % String(def.id)
	if String(def.id) == "cavern":
		return _pbr(key, TEX_ROCK_WALL, def.wall_color.lerp(Color.WHITE, 0.5), 0.26)
	return _pbr(key, TEX_BRICK, def.wall_color.lerp(Color.WHITE, 0.58), 0.32)


static func ceiling_mat(def: DungeonTypeDef) -> StandardMaterial3D:
	var key := "ceil_%s" % String(def.id)
	return _pbr(key, TEX_ROCK_WALL, def.wall_color.darkened(0.15).lerp(Color.WHITE, 0.4), 0.3)


static func wood_mat() -> StandardMaterial3D:
	return _pbr("wood", TEX_WOOD, Color(0.82, 0.7, 0.52), 0.55)


static func metal_mat() -> StandardMaterial3D:
	return _cached("metal", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.28, 0.27, 0.25)
		mat.metallic = 0.85
		mat.roughness = 0.38
		return mat
	)


static func flame_mat() -> StandardMaterial3D:
	return _cached("flame", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.55, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.08)
		mat.emission_energy_multiplier = 6.5
		mat.roughness = 1.0
		return mat
	)


static func portal_mat(color: Color) -> StandardMaterial3D:
	var key := "portal_%s" % color.to_html(false)
	return _cached(key, func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.4
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.72
		return mat
	)


static func _pbr(key: String, folder: String, tint: Color, uv_scale: float) -> StandardMaterial3D:
	return _cached(key, func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.albedo_texture = _tex(folder + "diff.jpg")
		var nor := _tex(folder + "nor.jpg")
		if nor:
			mat.normal_enabled = true
			mat.normal_texture = nor
			mat.normal_scale = 1.05
		var rough := _tex(folder + "rough.jpg")
		if rough:
			mat.roughness_texture = rough
		else:
			mat.roughness = 0.82
		var ao := _tex(folder + "ao.jpg")
		if ao:
			mat.ao_enabled = true
			mat.ao_texture = ao
			mat.ao_light_affect = 0.65
		mat.metallic = 0.0
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 4.0
		mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return mat
	)


static func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func _cached(key: String, factory: Callable) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var mat: StandardMaterial3D = factory.call()
	_cache[key] = mat
	return mat
