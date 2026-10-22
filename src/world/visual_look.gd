class_name VisualLook
extends RefCounted
## Environments, quality presets, and dungeon color grading.


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func using_forward_plus() -> bool:
	return String(RenderingServer.get_current_rendering_method()) == "forward_plus"


static func quality() -> String:
	var settings := _settings()
	return settings.graphics_quality if settings else "high"


static func apply_viewport(vp: Viewport, graphics_quality: String) -> void:
	if vp == null:
		return
	match graphics_quality:
		"low":
			vp.msaa_3d = Viewport.MSAA_DISABLED
		"medium":
			vp.msaa_3d = Viewport.MSAA_2X
		"ultra":
			vp.msaa_3d = Viewport.MSAA_4X
		_:
			vp.msaa_3d = Viewport.MSAA_2X


static func make_environment(def: DungeonTypeDef) -> Environment:
	var env := Environment.new()
	var q := quality()
	var crypt := def != null and String(def.id) != "cavern"
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.04) if crypt else Color(0.03, 0.03, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if crypt:
		env.ambient_light_color = Color(0.42, 0.52, 0.64)
	elif def:
		env.ambient_light_color = Color(0.40, 0.50, 0.48)
	else:
		env.ambient_light_color = Color(0.44, 0.50, 0.58)
	if not using_forward_plus() or q == "low":
		env.ambient_light_energy = 1.05
	else:
		env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.16, 0.20) if crypt else Color(0.14, 0.16, 0.14)
	env.fog_density = 0.008 if crypt else 0.007
	env.fog_aerial_perspective = 0.28
	env.adjustment_enabled = true
	if crypt:
		env.adjustment_brightness = 1.10
		env.adjustment_contrast = 1.06
		env.adjustment_saturation = 0.90
	else:
		env.adjustment_brightness = 1.12
		env.adjustment_contrast = 1.05
		env.adjustment_saturation = 0.96
	env.adjustment_color_correction = _grade(crypt)
	if not is_headless() and using_forward_plus():
		_enable_rich(env, q)
	return env


static func make_title_environment() -> Environment:
	var dummy := DungeonTypeDef.new()
	dummy.id = &"crypt"
	dummy.fog_color = Color(0.04, 0.045, 0.055)
	dummy.light_color = Color(0.55, 0.65, 0.8)
	var env := make_environment(dummy)
	env.fog_density = 0.01
	env.ambient_light_energy = 0.62 if not using_forward_plus() else 0.22
	env.glow_enabled = not is_headless()
	env.glow_intensity = 0.32
	env.glow_bloom = 0.05
	return env


static func attach_world(parent: Node3D, def: DungeonTypeDef) -> WorldEnvironment:
	var world := WorldEnvironment.new()
	world.name = "WorldLook"
	world.environment = make_environment(def)
	parent.add_child(world)
	var bounce := DirectionalLight3D.new()
	bounce.name = "Fill"
	bounce.rotation_degrees = Vector3(-55, 18, 0)
	bounce.light_color = Color(0.55, 0.66, 0.82) if def == null or String(def.id) != "cavern" else Color(0.52, 0.62, 0.58)
	bounce.light_energy = 0.55 if quality() == "low" or not using_forward_plus() else 0.14
	bounce.shadow_enabled = false
	parent.add_child(bounce)
	return world


static func configure_omni(light: OmniLight3D, cast_shadow: bool) -> void:
	var q := quality()
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.distance_fade_enabled = true
	light.distance_fade_begin = 16.0
	light.distance_fade_length = 7.0
	if is_headless() or q == "low" or not cast_shadow or not using_forward_plus():
		light.shadow_enabled = false
		return
	light.shadow_enabled = true
	light.shadow_bias = 0.08
	light.shadow_opacity = 0.72
	if q == "ultra":
		light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE


static func _enable_rich(env: Environment, q: String) -> void:
	if q == "low":
		return
	env.ssao_enabled = true
	env.ssao_radius = 1.05
	env.ssao_intensity = 1.55
	env.glow_enabled = q != "medium"
	env.glow_intensity = 0.28
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2
	if q == "medium":
		return
	env.ssil_enabled = true
	env.ssil_intensity = 0.55
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = env.fog_light_color
	env.volumetric_fog_emission = Color(0.08, 0.09, 0.11)
	env.volumetric_fog_emission_energy = 0.05
	env.volumetric_fog_anisotropy = 0.22
	if q == "ultra":
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_bounce_feedback = 0.28
		env.sdfgi_energy = 0.42


static func _grade(crypt: bool) -> GradientTexture1D:
	var grad := Gradient.new()
	if crypt:
		grad.colors = PackedColorArray([
			Color(0.04, 0.05, 0.08),
			Color(0.16, 0.16, 0.20),
			Color(0.62, 0.58, 0.54),
			Color(0.96, 0.93, 0.86),
		])
	else:
		grad.colors = PackedColorArray([
			Color(0.04, 0.05, 0.04),
			Color(0.16, 0.17, 0.14),
			Color(0.62, 0.56, 0.46),
			Color(0.96, 0.92, 0.82),
		])
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 256
	return tex


static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("SettingsService")
