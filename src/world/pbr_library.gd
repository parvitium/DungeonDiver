class_name PBRLibrary
extends RefCounted
## Cached PBR materials. Mesh UVs are in world metres; uv1_scale is 1 / metres-per-tile.

const METERS_BRICK := 1.7
const METERS_FLOOR := 1.6
const METERS_ROCK := 2.0
const METERS_WOOD := 1.5
const METERS_METAL := 1.4
const METERS_BONE := 1.2

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func meters_to_uv(meters: float) -> Vector3:
	var s := 1.0 / maxf(0.75, meters)
	return Vector3(s, s, 1.0)


static func wall(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_rock", Color(0.88, 0.84, 0.76), 0.92, 0.0, METERS_ROCK, 1.05)
	return _pbr("crypt_brick", Color(1.0, 0.98, 0.94), 0.84, 0.0, METERS_BRICK, 1.05)


static func floor_mat(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_floor", Color(0.80, 0.76, 0.66), 0.94, 0.0, METERS_FLOOR, 0.9)
	return _pbr("crypt_floor", Color(0.86, 0.87, 0.88), 0.88, 0.0, METERS_FLOOR, 0.95)


static func ceiling(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_rock", Color(0.70, 0.68, 0.60), 0.96, 0.0, METERS_ROCK, 0.7)
	return _pbr("crypt_brick", Color(0.88, 0.86, 0.80), 0.88, 0.0, METERS_BRICK, 0.7)


static func wood() -> StandardMaterial3D:
	return _pbr("wood", Color(0.78, 0.58, 0.36), 0.78, 0.0, METERS_WOOD, 0.7)


static func metal() -> StandardMaterial3D:
	return _pbr("metal", Color(0.62, 0.58, 0.52), 0.42, 0.78, METERS_METAL, 1.15)


static func bone() -> StandardMaterial3D:
	# Ivory aged bone: plaster albedo, cool-white tint, dry roughness. Not sand.
	return _pbr("bone", Color(0.93, 0.89, 0.80), 0.62, 0.02, METERS_BONE, 0.45)


static func trim(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_rock", Color(0.42, 0.40, 0.34), 0.9, 0.04, 1.2, 0.85)
	return _pbr("crypt_brick", Color(0.55, 0.56, 0.58), 0.7, 0.18, 1.2, 0.8)


static func wear(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_rock", Color(0.32, 0.30, 0.26), 0.95, 0.02, 1.1, 0.6)
	return _pbr("crypt_brick", Color(0.38, 0.36, 0.34), 0.82, 0.08, 1.1, 0.55)


static func cloth(color: Color) -> StandardMaterial3D:
	var key := "cloth:%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := tinted(_pbr("cloth", Color(1, 1, 1), 0.90, 0.0, 0.85, 0.55), color)
	if mat.albedo_texture == null:
		mat.roughness = 0.88
		mat.metallic = 0.0
	_cache[key] = mat
	return mat


static func hide() -> StandardMaterial3D:
	return _pbr("hide", Color(0.72, 0.54, 0.36), 0.78, 0.0, 0.9, 0.85)


static func skin() -> StandardMaterial3D:
	return _pbr("skin", Color(0.82, 0.78, 0.52), 0.62, 0.0, 0.48, 1.55)


static func fur() -> StandardMaterial3D:
	return _pbr("fur", Color(0.78, 0.62, 0.42), 0.88, 0.0, 0.42, 1.55)


static func wet(theme: StringName) -> StandardMaterial3D:
	var key := "wet:%s" % String(theme)
	if _cache.has(key):
		return _cache[key]
	var mat := wall(theme).duplicate() as StandardMaterial3D
	mat.roughness = 0.22
	mat.metallic = 0.16
	mat.albedo_color = mat.albedo_color.darkened(0.28)
	_cache[key] = mat
	return mat


static func puddle() -> StandardMaterial3D:
	if _cache.has("puddle"):
		return _cache["puddle"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.13, 0.16, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.55
	mat.metallic_specular = 0.7
	var normal_tex := _tex("crypt_floor", "normal.jpg")
	if normal_tex:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = 0.35
	mat.uv1_scale = meters_to_uv(1.6)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache["puddle"] = mat
	return mat


static func shaft() -> StandardMaterial3D:
	if _cache.has("shaft"):
		return _cache["shaft"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.84, 0.62, 0.07)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.82, 0.55)
	mat.emission_energy_multiplier = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache["shaft"] = mat
	return mat


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var key := "emit:%s:%.2f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.35
	_cache[key] = mat
	return mat


static func tinted(base: StandardMaterial3D, color: Color) -> StandardMaterial3D:
	var mat := base.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	return mat


static func _pbr(folder: String, albedo: Color, roughness: float, metallic: float, meters: float, normal_scale: float) -> StandardMaterial3D:
	var key := "%s:%.2f:%.2f:%.2f:%.2f" % [folder, roughness, metallic, meters, normal_scale]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	mat.uv1_scale = meters_to_uv(meters)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.texture_repeat = true
	var albedo_tex := _tex(folder, "albedo.jpg")
	if albedo_tex:
		mat.albedo_texture = albedo_tex
	var normal_tex := _tex(folder, "normal.jpg")
	if normal_tex:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = normal_scale
	var rough_tex := _tex(folder, "roughness.jpg")
	if rough_tex:
		mat.roughness_texture = rough_tex
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	var ao_tex := _tex(folder, "ao.jpg")
	if ao_tex:
		mat.ao_enabled = true
		mat.ao_texture = ao_tex
		mat.ao_light_affect = 0.55
	if metallic > 0.4:
		mat.metallic_specular = 0.55
	_cache[key] = mat
	return mat


static func _tex(folder: String, file: String) -> Texture2D:
	var path := "res://assets/textures/%s/%s" % [folder, file]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
