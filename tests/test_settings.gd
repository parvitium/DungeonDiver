class_name TestSettings
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("settings")
	var settings := DDTest.autoload("SettingsService")
	t.assert_true(settings != null, "SettingsService autoload")
	if settings == null:
		return t
	settings.apply_dict({
		"mouse_sensitivity": 9.0,
		"fov": 12.0,
		"master_volume": 4.0,
		"graphics_quality": "nope",
	})
	t.assert_in_range(settings.mouse_sensitivity, 0.2, 3.0, "sens clamped")
	t.assert_in_range(settings.fov, 50.0, 110.0, "fov clamped")
	t.assert_in_range(settings.master_volume, 0.0, 1.0, "volume clamped")
	t.assert_true(SettingsService.QUALITIES.has(settings.graphics_quality), "quality stays valid")

	settings.set_mouse_sensitivity(1.4)
	settings.set_fov(82.0)
	settings.set_master_volume(0.25)
	settings.set_graphics_quality("low")
	t.assert_eq(settings.graphics_quality, "low", "quality set")
	t.assert_true(settings.save_settings(), "save settings")
	settings.graphics_quality = "ultra"
	settings.fov = 99.0
	t.assert_true(settings.load_settings(), "reload settings")
	t.assert_eq(settings.graphics_quality, "low", "quality persisted")
	t.assert_eq(settings.fov, 82.0, "fov persisted")
	settings.set_graphics_quality("high")

	var env := VisualLook.make_environment(Catalog.all_dungeons()[0])
	t.assert_true(env.fog_enabled, "fog on")
	t.assert_true(env.adjustment_enabled, "color grade on")
	t.assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX, "AgX tonemap")
	var title_env := VisualLook.make_title_environment()
	t.assert_true(title_env.fog_enabled, "title fog")
	return t
