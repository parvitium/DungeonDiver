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
	env.background_color = def.fog_color.darkened(0.15) if def else Color(0.03, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if def:
		env.ambient_light_color = def.light_color.lerp(Color(0.55, 0.42, 0.3), 0.45)
	else:
		env.ambient_light_color = Color(0.45, 0.32, 0.2)
	if not using_forward_plus() or q == "low":
		env.ambient_light_energy = 0.55
	else:
		env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = def.fog_color.lightened(0.12) if def else Color(0.12, 0.08, 0.06)
	env.fog_density = 0.01 if crypt else 0.008
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	if crypt:
		env.adjustment_brightness = 1.02
		env.adjustment_contrast = 1.12
		env.adjustment_saturation = 0.92
	else:
		env.adjustment_brightness = 1.06
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.05
	env.adjustment_color_correction = _grade(crypt)
	if not is_headless() and using_forward_plus():
		_enable_rich(env, q)
	return env


static func make_title_environment() -> Environment:
	var dummy := DungeonTypeDef.new()
	dummy.id = &"crypt"
	dummy.fog_color = Color(0.035, 0.025, 0.03)
	dummy.light_color = Color(1.0, 0.62, 0.32)
	var env := make_environment(dummy)
	env.fog_density = 0.016
	env.ambient_light_energy = 0.32 if not using_forward_plus() else 0.14
	env.glow_enabled = not is_headless()
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	return env


static func attach_world(parent: Node3D, def: DungeonTypeDef) -> WorldEnvironment:
	var world := WorldEnvironment.new()
	world.name = "WorldLook"
	world.environment = make_environment(def)
	parent.add_child(world)
	var bounce := DirectionalLight3D.new()
	bounce.name = "Fill"
	bounce.rotation_degrees = Vector3(-48, 28, 0)
	bounce.light_color = def.light_color.lerp(Color(1, 0.75, 0.5), 0.4) if def else Color(1, 0.75, 0.5)
	bounce.light_energy = 0.45 if quality() == "low" or not using_forward_plus() else 0.16
	bounce.shadow_enabled = false
	parent.add_child(bounce)
	return world


static func configure_omni(light: OmniLight3D, cast_shadow: bool) -> void:
	var q := quality()
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.distance_fade_enabled = true
	light.distance_fade_begin = 18.0
	light.distance_fade_length = 8.0
	if is_headless() or q == "low" or not cast_shadow or not using_forward_plus():
		light.shadow_enabled = false
		return
	light.shadow_enabled = true
	light.shadow_bias = 0.08
	light.shadow_opacity = 0.78
	if q == "ultra":
		light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE


static func _enable_rich(env: Environment, q: String) -> void:
	if q == "low":
		return
	env.ssao_enabled = true
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.8
	env.glow_enabled = q != "medium"
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	if q == "medium":
		return
	env.ssil_enabled = true
	env.ssil_intensity = 0.7
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = env.fog_light_color
	env.volumetric_fog_emission = env.fog_light_color.darkened(0.7)
	env.volumetric_fog_emission_energy = 0.08
	env.volumetric_fog_anisotropy = 0.25
	if q == "ultra":
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_bounce_feedback = 0.35
		env.sdfgi_energy = 0.55


static func _grade(crypt: bool) -> GradientTexture1D:
	var grad := Gradient.new()
	if crypt:
		grad.colors = PackedColorArray([
			Color(0.04, 0.03, 0.07),
			Color(0.22, 0.14, 0.18),
			Color(0.72, 0.58, 0.48),
			Color(1.0, 0.92, 0.78),
		])
	else:
		grad.colors = PackedColorArray([
			Color(0.05, 0.03, 0.02),
			Color(0.28, 0.16, 0.08),
			Color(0.85, 0.58, 0.32),
			Color(1.0, 0.94, 0.8),
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
