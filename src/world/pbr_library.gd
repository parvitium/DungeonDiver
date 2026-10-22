class_name PBRLibrary
extends RefCounted
## Cached PBR materials from CC0 albedo/normal/roughness/AO maps.

const TILE := 1.15

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func wall(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_rock", Color(0.55, 0.42, 0.32), 0.92, 0.0, Vector3(1.6, 1.6, 1.0))
	return _pbr("crypt_brick", Color(0.62, 0.48, 0.4), 0.88, 0.02, Vector3(1.35, 1.35, 1.0))


static func floor_mat(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_floor", Color(0.42, 0.32, 0.22), 0.95, 0.0, Vector3(1.8, 1.8, 1.0))
	return _pbr("crypt_floor", Color(0.38, 0.34, 0.3), 0.9, 0.0, Vector3(1.25, 1.25, 1.0))


static func ceiling(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_rock", Color(0.35, 0.28, 0.22), 0.96, 0.0, Vector3(1.4, 1.4, 1.0))
	return _pbr("crypt_brick", Color(0.32, 0.28, 0.26), 0.94, 0.0, Vector3(1.1, 1.1, 1.0))


static func wood() -> StandardMaterial3D:
	return _pbr("wood", Color(0.42, 0.28, 0.16), 0.82, 0.0, Vector3(1.7, 1.7, 1.0))


static func metal() -> StandardMaterial3D:
	return _pbr("metal", Color(0.45, 0.38, 0.32), 0.45, 0.72, Vector3(2.2, 2.2, 1.0))


static func bone() -> StandardMaterial3D:
	var mat := _pbr("bone", Color(0.86, 0.8, 0.68), 0.7, 0.0, Vector3(2.4, 2.4, 1.0))
	mat.albedo_color = Color(0.9, 0.82, 0.68)
	return mat


static func trim(theme: StringName) -> StandardMaterial3D:
	if theme == &"cavern":
		return _pbr("cavern_rock", Color(0.28, 0.22, 0.16), 0.9, 0.05, Vector3(2.4, 2.4, 1.0))
	return metal()


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


static func _pbr(folder: String, albedo: Color, roughness: float, metallic: float, uv_scale: Vector3) -> StandardMaterial3D:
	var key := "%s:%.2f:%.2f:%s" % [folder, roughness, metallic, str(uv_scale)]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = metallic
	mat.uv1_scale = uv_scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var albedo_tex := _tex(folder, "albedo.jpg")
	if albedo_tex:
		mat.albedo_texture = albedo_tex
		mat.albedo_color = Color(0.92, 0.9, 0.86)
	var normal_tex := _tex(folder, "normal.jpg")
	if normal_tex:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = 1.05
	var rough_tex := _tex(folder, "roughness.jpg")
	if rough_tex:
		mat.roughness_texture = rough_tex
	var ao_tex := _tex(folder, "ao.jpg")
	if ao_tex:
		mat.ao_enabled = true
		mat.ao_texture = ao_tex
		mat.ao_light_affect = 0.7
	if metallic > 0.4:
		mat.metallic_specular = 0.55
	_cache[key] = mat
	return mat


static func _tex(folder: String, file: String) -> Texture2D:
	var path := "res://assets/textures/%s/%s" % [folder, file]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
