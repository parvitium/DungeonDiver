class_name Player
extends CharacterBody3D
## Presentation + pawn. Movement/combat apply PlayerCommand so a future host
## can run the same function on replicated intent.

signal died
signal vitals_changed
signal prompt_changed(text: String)

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.2
const JUMP_VELOCITY := 7.2
const MOUSE_SENS := 0.0024
const MELEE_COST := 14.0
const SPELL_COST := 22.0
const SPRINT_COST := 18.0
const BLOCK_HIT_COST := 12.0
const STAMINA_REGEN := 16.0
const REGEN_DELAY := 0.55
const MELEE_TIME := 0.28
const MELEE_COOLDOWN := 0.45
const SPELL_COOLDOWN := 0.7

var look_pitch: float = 0.0
var pending_look: Vector2 = Vector2.ZERO
var stamina: float = 100.0
var health: float = 100.0
var stamina_lock: float = 0.0
var melee_timer: float = 0.0
var melee_cd: float = 0.0
var spell_cd: float = 0.0
var blocking: bool = false
var alive: bool = true
var input_enabled: bool = true

var _camera: Camera3D
var _melee_area: Area3D
var _interact_ray: RayCast3D
var _weapon_visual: Node3D
var _shield_visual: Node3D
var _focus_prompt: String = ""


func _ready() -> void:
	add_to_group("player")
	collision_layer = DD.PLAYER_LAYER
	collision_mask = DD.WORLD_LAYER | DD.MONSTER_LAYER
	floor_stop_on_slope = true
	_build_rig()
	_sync_from_profile()
	if not GameSession.profile_changed.is_connected(_on_profile_changed):
		GameSession.profile_changed.connect(_on_profile_changed)


func _build_rig() -> void:
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	capsule.shape = shape
	capsule.position = Vector3(0, 0.85, 0)
	add_child(capsule)

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.55, 0)
	add_child(head)

	_camera = Camera3D.new()
	_camera.fov = _fov()
	head.add_child(_camera)
	var lamp := OmniLight3D.new()
	lamp.name = "ViewLamp"
	lamp.position = Vector3(0.15, -0.05, -0.25)
	lamp.light_color = Color(1.0, 0.82, 0.6)
	lamp.light_energy = 0.55
	lamp.omni_range = 2.8
	lamp.shadow_enabled = false
	head.add_child(lamp)
	var settings := get_node_or_null("/root/SettingsService")
	if settings and settings.has_signal("changed") and not settings.changed.is_connected(_on_settings_changed):
		settings.changed.connect(_on_settings_changed)

	_interact_ray = RayCast3D.new()
	_interact_ray.target_position = Vector3(0, 0, -2.6)
	_interact_ray.collision_mask = DD.INTERACT_LAYER
	_interact_ray.collide_with_areas = true
	_interact_ray.collide_with_bodies = false
	head.add_child(_interact_ray)

	_melee_area = Area3D.new()
	_melee_area.position = Vector3(0, 0, -1.4)
	_melee_area.collision_layer = 0
	_melee_area.collision_mask = DD.MONSTER_LAYER
	_melee_area.monitoring = false
	_melee_area.monitorable = false
	var melee_shape := CollisionShape3D.new()
	var melee_box := BoxShape3D.new()
	melee_box.size = Vector3(1.3, 1.1, 1.8)
	melee_shape.shape = melee_box
	_melee_area.add_child(melee_shape)
	head.add_child(_melee_area)

	_weapon_visual = _viewmodel(AssetLibrary.weapon_path("sword"), Vector3(0.06, 0.04, 0.72), PBRLibrary.metal(), "WeaponVisual", Vector3(68, 188, 6), 0.48)
	_weapon_visual.position = Vector3(0.4, -0.36, -0.5)
	_weapon_visual.rotation_degrees = Vector3(10, 8, 14)
	head.add_child(_weapon_visual)

	_shield_visual = _viewmodel(AssetLibrary.weapon_path("shield"), Vector3(0.34, 0.46, 0.06), PBRLibrary.wood(), "ShieldVisual", Vector3(8, 180, 0), 0.55)
	_shield_visual.position = Vector3(-0.3, -0.2, -0.4)
	_shield_visual.rotation_degrees = Vector3(4, 10, -8)
	_shield_visual.visible = false
	head.add_child(_shield_visual)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or GameSession.ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pending_look += event.relative


func gather_command() -> PlayerCommand:
	var cmd := PlayerCommand.new()
	if not input_enabled or GameSession.ui_open or not alive:
		return cmd
	cmd.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	cmd.look_delta = pending_look
	pending_look = Vector2.ZERO
	cmd.jump = Input.is_action_just_pressed("jump")
	cmd.sprint = Input.is_action_pressed("sprint")
	cmd.melee = Input.is_action_just_pressed("melee")
	cmd.block = Input.is_action_pressed("block")
	cmd.cast = Input.is_action_just_pressed("cast")
	cmd.interact = Input.is_action_just_pressed("interact")
	return cmd


func apply_command(cmd: PlayerCommand, delta: float) -> void:
	if not alive:
		return
	var stats := GameSession.profile.total_stats()
	_apply_look(cmd.look_delta)
	_apply_move(cmd, delta, stats)
	_apply_combat(cmd, delta, stats)
	if cmd.interact:
		_try_interact()
	_update_prompt()
	_write_back_profile()
	vitals_changed.emit()


func _physics_process(_delta: float) -> void:
	if GameSession.accept_local_input:
		GameSession.submit_command(gather_command())


func _apply_look(look_delta: Vector2) -> void:
	var sens := MOUSE_SENS * _mouse_scale()
	rotate_y(-look_delta.x * sens)
	look_pitch = clampf(look_pitch - look_delta.y * sens, deg_to_rad(-85.0), deg_to_rad(85.0))
	if _camera:
		_camera.get_parent().rotation.x = look_pitch
		_camera.fov = _fov()


func _apply_move(cmd: PlayerCommand, delta: float, stats: StatBlock) -> void:
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	elif cmd.jump:
		velocity.y = JUMP_VELOCITY

	var sprinting := cmd.sprint and cmd.move.length() > 0.1 and stamina > 1.0 and not cmd.block
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if sprinting:
		_spend_stamina(SPRINT_COST * delta, stats)

	var basis_z := -global_transform.basis.z
	var basis_x := global_transform.basis.x
	basis_z.y = 0
	basis_x.y = 0
	basis_z = basis_z.normalized()
	basis_x = basis_x.normalized()
	var wish := (basis_x * cmd.move.x + basis_z * -cmd.move.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target := wish * speed
	velocity.x = target.x
	velocity.z = target.z
	move_and_slide()


func _apply_combat(cmd: PlayerCommand, delta: float, stats: StatBlock) -> void:
	melee_cd = maxf(0.0, melee_cd - delta)
	spell_cd = maxf(0.0, spell_cd - delta)
	stamina_lock = maxf(0.0, stamina_lock - delta)
	if melee_timer > 0.0:
		melee_timer -= delta
		if melee_timer <= 0.0:
			_melee_area.monitoring = false
	blocking = cmd.block and stamina > 1.0 and melee_timer <= 0.0
	if _shield_visual:
		_shield_visual.visible = blocking
	if blocking:
		_weapon_visual.position = Vector3(0.42, -0.32, -0.35)
	else:
		_weapon_visual.position = Vector3(0.35, -0.28, -0.45)

	if cmd.melee and melee_cd <= 0.0 and melee_timer <= 0.0 and _spend_stamina(MELEE_COST, stats):
		_do_melee(stats)
	if cmd.cast and spell_cd <= 0.0 and _spend_stamina(SPELL_COST, stats):
		_do_spell(stats)

	if stamina_lock <= 0.0:
		stamina = minf(stats.max_stamina, stamina + STAMINA_REGEN * delta)


func _do_melee(stats: StatBlock) -> void:
	melee_timer = MELEE_TIME
	melee_cd = MELEE_COOLDOWN
	_melee_area.monitoring = true
	var power := CombatResolver.player_melee_power(stats)
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.1, 1.8)
	params.shape = box
	params.transform = _melee_area.global_transform
	params.collision_mask = DD.MONSTER_LAYER
	params.collide_with_bodies = true
	for hit in space.intersect_shape(params, 16):
		var collider: Variant = hit.get("collider")
		if collider is Node and collider.has_method("receive_hit"):
			collider.receive_hit(power, global_position, false)
	_weapon_visual.rotation_degrees = Vector3(40, 8, 18)
	var tween := create_tween()
	tween.tween_property(_weapon_visual, "rotation_degrees", Vector3(12, 8, 18), 0.18)


func _do_spell(stats: StatBlock) -> void:
	spell_cd = SPELL_COOLDOWN
	var bolt := Projectile.new()
	var origin := _camera.global_position + -_camera.global_transform.basis.z * 0.7
	var dir := -_camera.global_transform.basis.z
	get_parent().add_child(bolt)
	bolt.setup(origin, dir, CombatResolver.player_spell_power(stats), 24.0, true, Color(1.0, 0.45, 0.15))


func receive_hit(raw_damage: float, _from: Vector3, already_mitigated: bool) -> void:
	if not alive:
		return
	var stats := GameSession.profile.total_stats()
	var dmg := raw_damage if already_mitigated else CombatResolver.mitigated_damage(raw_damage, stats.defense)
	if blocking:
		dmg = CombatResolver.apply_block(dmg, true)
		_spend_stamina(BLOCK_HIT_COST, stats)
	health = maxf(0.0, health - dmg)
	GameSession.log_message.emit("-%s HP" % str(dmg), Color(1.0, 0.4, 0.35))
	if health <= 0.0:
		alive = false
		died.emit()
	_write_back_profile()
	vitals_changed.emit()


func _spend_stamina(cost: float, stats: StatBlock) -> bool:
	if stamina < cost * 0.5 and cost > 1.0:
		return false
	stamina = maxf(0.0, stamina - cost)
	stamina_lock = REGEN_DELAY
	stamina = minf(stamina, stats.max_stamina)
	return true


func _try_interact() -> void:
	if _interact_ray == null or not _interact_ray.is_colliding():
		return
	var collider := _interact_ray.get_collider()
	if collider is Interactable:
		collider.try_use(self)


func _update_prompt() -> void:
	var text := ""
	if _interact_ray and _interact_ray.is_colliding():
		var collider := _interact_ray.get_collider()
		if collider is Interactable and not collider.used:
			if collider.locked:
				text = "Sealed — defeat the boss"
			else:
				text = "E — %s" % collider.prompt
	if text != _focus_prompt:
		_focus_prompt = text
		prompt_changed.emit(text)


func _sync_from_profile() -> void:
	var stats := GameSession.profile.total_stats()
	health = GameSession.profile.current_health
	stamina = GameSession.profile.current_stamina
	if health <= 0.0:
		health = stats.max_health
	health = minf(health, stats.max_health)
	stamina = minf(stamina, stats.max_stamina)


func _write_back_profile() -> void:
	GameSession.profile.current_health = health
	GameSession.profile.current_stamina = stamina


func _on_profile_changed() -> void:
	var stats := GameSession.profile.total_stats()
	health = minf(health, stats.max_health)
	stamina = minf(stamina, stats.max_stamina)
	vitals_changed.emit()


func _on_settings_changed() -> void:
	if _camera:
		_camera.fov = _fov()


func _fov() -> float:
	var settings := get_node_or_null("/root/SettingsService")
	return settings.fov if settings else 75.0


func _mouse_scale() -> float:
	var settings := get_node_or_null("/root/SettingsService")
	return settings.mouse_sensitivity if settings else 1.0


func _viewmodel(path: String, fallback_size: Vector3, material: Material, name: String, mesh_rot: Vector3, mesh_scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var authored := AssetLibrary.instance(path)
	if authored:
		authored.name = "Mesh"
		_paint_meshes(authored, material)
		authored.rotation_degrees = mesh_rot
		authored.scale = Vector3.ONE * mesh_scale
		root.add_child(authored)
		return root
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = fallback_size
	mesh.mesh = box
	mesh.material_override = material
	root.add_child(mesh)
	return root


func _paint_meshes(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_paint_meshes(child, material)
