class_name ScenicBackdrop
extends RefCounted
## Shared dungeon-hall look for the main menu and town hub.


static func attach(host: Node3D, camera_z: float = 9.2) -> Camera3D:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.03, 0.028)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.32, 0.22)
	e.ambient_light_energy = 0.42
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.08, 0.05)
	e.fog_density = 0.028
	e.glow_enabled = true
	e.glow_intensity = 0.35
	env.environment = e
	host.add_child(env)

	var floor := Greybox.make_box(Vector3(22, 0.4, 22), Color(0.18, 0.14, 0.1))
	floor.position = Vector3(0, -0.2, 0)
	host.add_child(floor)
	var back := Greybox.make_box(Vector3(18, 8, 0.6), Color(0.16, 0.13, 0.1))
	back.position = Vector3(0, 4, -8)
	host.add_child(back)
	var left := Greybox.make_box(Vector3(0.6, 8, 16), Color(0.15, 0.12, 0.09))
	left.position = Vector3(-9, 4, -1)
	host.add_child(left)
	var right := Greybox.make_box(Vector3(0.6, 8, 16), Color(0.15, 0.12, 0.09))
	right.position = Vector3(9, 4, -1)
	host.add_child(right)
	var arch := Greybox.make_box(Vector3(6.4, 5.2, 0.5), Color(0.28, 0.22, 0.16))
	arch.position = Vector3(0, 2.6, -7.4)
	host.add_child(arch)
	var opening := Greybox.make_box(Vector3(3.2, 3.6, 0.7), Color(0.04, 0.03, 0.03))
	opening.position = Vector3(0, 2.1, -7.35)
	host.add_child(opening)
	var pedestal := Greybox.make_box(Vector3(2.4, 1.0, 2.4), Color(0.32, 0.22, 0.12))
	pedestal.position = Vector3(0, 0.5, -1.2)
	host.add_child(pedestal)
	var relic := Greybox.make_box(Vector3(0.28, 1.6, 0.28), Color(0.78, 0.72, 0.42), false)
	relic.position = Vector3(0, 1.7, -1.2)
	host.add_child(relic)
	var torch_l := OmniLight3D.new()
	torch_l.position = Vector3(-3.4, 3.4, -4.2)
	torch_l.light_color = Color(1.0, 0.62, 0.28)
	torch_l.light_energy = 4.2
	torch_l.omni_range = 14
	host.add_child(torch_l)
	var torch_r := OmniLight3D.new()
	torch_r.position = Vector3(3.4, 3.4, -4.2)
	torch_r.light_color = Color(1.0, 0.55, 0.22)
	torch_r.light_energy = 3.4
	torch_r.omni_range = 12
	host.add_child(torch_r)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.05, camera_z)
	host.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.4, -1.6), Vector3.UP)
	return cam
