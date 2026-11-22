class_name Player
extends CharacterBody3D
## Presentation + pawn. Movement/combat apply PlayerCommand so a future host
## can run the same function on replicated intent.

signal died
signal vitals_changed
signal prompt_changed(text: String)
signal took_hit(amount: float, from: Vector3)

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
const MELEE_RANGE := StrikeQuery.MELEE_RANGE
const MELEE_CONE_DEG := StrikeQuery.MELEE_CONE_DEG
const MELEE_ACTIVE_START := 0.05
const MELEE_ACTIVE_END := 0.22
const INTERACT_RANGE := StrikeQuery.INTERACT_RANGE
const WEAPON_REST_POS := Vector3(0.46, -0.4, -0.62)
const WEAPON_REST_ROT := Vector3(18, 28, 14)
const WEAPON_BLOCK_POS := Vector3(0.28, -0.3, -0.48)

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
var last_hit_from: Vector3 = Vector3.ZERO
var last_hit_amount: float = 0.0

var _camera: Camera3D
var _head: Node3D
var _weapon_visual: Node3D
var _shield_visual: MeshInstance3D
var _focus_prompt: String = ""
var _consume_click_for_capture: bool = false
var _rig_built: bool = false
var _melee_hits: Dictionary = {}
var _melee_power: float = 0.0
var _shake: float = 0.0
var _hurt_player: AudioStreamPlayer
var _hit_player: AudioStreamPlayer
var _swing_trail: GPUParticles3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = DD.PLAYER_LAYER
	collision_mask = DD.WORLD_LAYER | DD.MONSTER_LAYER
	floor_stop_on_slope = true
	_build_rig()
	_sync_from_profile()
	if not GameSession.profile_changed.is_connected(_on_profile_changed):
		GameSession.profile_changed.connect(_on_profile_changed)
	var win := get_window()
	if win and not win.focus_entered.is_connected(_on_window_focus):
		win.focus_entered.connect(_on_window_focus)


func _build_rig() -> void:
	if _rig_built:
		return
	_rig_built = true
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	capsule.shape = shape
	capsule.position = Vector3(0, 0.85, 0)
	add_child(capsule)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.55, 0)
	add_child(_head)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 75.0
	_camera.current = true
	_head.add_child(_camera)

	_weapon_visual = _make_held_sword()
	_swing_trail = CombatVfx.make_swing_trail()
	_swing_trail.position = Vector3(0, 0, -0.22)
	_weapon_visual.add_child(_swing_trail)
	_head.add_child(_weapon_visual)

	_shield_visual = MeshInstance3D.new()
	_shield_visual.name = "ShieldVisual"
	var shield := BoxMesh.new()
	shield.size = Vector3(0.45, 0.6, 0.06)
	_shield_visual.mesh = shield
	_shield_visual.material_override = Greybox.make_material(Color(0.45, 0.32, 0.2))
	_shield_visual.position = Vector3(-0.32, -0.22, -0.4)
	_shield_visual.visible = false
	_head.add_child(_shield_visual)

	_hurt_player = AudioStreamPlayer.new()
	_hurt_player.stream = Sfx.hurt_grunt()
	_hurt_player.volume_db = -2.0
	add_child(_hurt_player)
	_hit_player = AudioStreamPlayer.new()
	_hit_player.stream = Sfx.flesh_hit()
	_hit_player.volume_db = -6.0
	add_child(_hit_player)


func _make_held_sword() -> Node3D:
	var kit := Node3D.new()
	kit.name = "WeaponVisual"
	kit.position = WEAPON_REST_POS
	kit.rotation_degrees = WEAPON_REST_ROT

	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.016
	handle_mesh.bottom_radius = 0.02
	handle_mesh.height = 0.13
	handle.mesh = handle_mesh
	handle.material_override = Greybox.make_material(Color(0.28, 0.16, 0.08))
	handle.rotation_degrees = Vector3(90, 0, 0)
	handle.position = Vector3(0, 0, 0.08)
	kit.add_child(handle)

	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.16, 0.028, 0.028)
	guard.mesh = guard_mesh
	guard.material_override = Greybox.make_material(Color(0.62, 0.52, 0.28))
	guard.position = Vector3(0, 0, 0.0)
	kit.add_child(guard)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.038, 0.012, 0.42)
	blade.mesh = blade_mesh
	blade.material_override = Greybox.make_material(Color(0.78, 0.8, 0.84))
	blade.position = Vector3(0, 0, -0.22)
	kit.add_child(blade)
	return kit


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 9.0)
		var mag := _shake * 0.035
		_camera.position = Vector3(
			randf_range(-mag, mag),
			randf_range(-mag, mag),
			randf_range(-mag * 0.4, mag * 0.4)
		)
	else:
		_camera.position = Vector3.ZERO


func _input(event: InputEvent) -> void:
	if handle_look_input(event) and is_inside_tree():
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func handle_look_input(event: InputEvent) -> bool:
	if not input_enabled:
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ctx := MouseCapture.context_for(true, GameSession.ui_open)
		if MouseCapture.should_recapture_click(ctx, MouseCapture.is_captured()):
			MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)
			_consume_click_for_capture = true
			return true
	if GameSession.ui_open:
		return false
	if event is InputEventMouseMotion and MouseCapture.allows_look():
		pending_look += event.relative
		return true
	return false


func gather_command() -> PlayerCommand:
	var cmd := PlayerCommand.new()
	if not input_enabled or GameSession.ui_open or not alive:
		_consume_click_for_capture = false
		pending_look = Vector2.ZERO
		return cmd
	cmd.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	cmd.look_delta = GameSession.look_settings.scale_delta(pending_look)
	pending_look = Vector2.ZERO
	cmd.jump = Input.is_action_just_pressed("jump")
	cmd.sprint = Input.is_action_pressed("sprint")
	cmd.melee = Input.is_action_just_pressed("melee") and not _consume_click_for_capture
	_consume_click_for_capture = false
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
	rotate_y(-look_delta.x * MOUSE_SENS)
	look_pitch = MouseCapture.clamp_pitch(look_pitch - look_delta.y * MOUSE_SENS)
	if _head:
		_head.rotation.x = look_pitch
	elif _camera:
		_camera.get_parent().rotation.x = look_pitch


func head_pitch() -> float:
	return look_pitch


func focus_prompt() -> String:
	return _focus_prompt


func aim_camera_at(world: Vector3) -> void:
	_build_rig()
	var origin := global_position
	var flat := Vector3(world.x, origin.y, world.z)
	if flat.distance_to(origin) > 0.05:
		look_at(flat, Vector3.UP)
	if _camera == null:
		return
	var to := world - _camera.global_position
	var horiz := Vector2(to.x, to.z).length()
	look_pitch = atan2(to.y, maxf(horiz, 0.001))
	look_pitch = MouseCapture.clamp_pitch(look_pitch)
	if _head:
		_head.rotation.x = look_pitch


func _on_window_focus() -> void:
	if input_enabled and not GameSession.ui_open and alive:
		MouseCapture.apply(MouseCapture.Context.DUNGEON_PLAY)


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
		var elapsed := MELEE_TIME - melee_timer
		melee_timer -= delta
		if elapsed >= MELEE_ACTIVE_START and elapsed <= MELEE_ACTIVE_END:
			_melee_tick()
		if _swing_trail:
			_swing_trail.emitting = true
	elif _swing_trail:
		_swing_trail.emitting = false
	blocking = cmd.block and stamina > 1.0 and melee_timer <= 0.0
	if _shield_visual:
		_shield_visual.visible = blocking
	if _weapon_visual:
		_weapon_visual.position = WEAPON_BLOCK_POS if blocking else WEAPON_REST_POS

	if cmd.melee and melee_cd <= 0.0 and melee_timer <= 0.0 and _spend_stamina(MELEE_COST, stats):
		_do_melee(stats)
	if cmd.cast and spell_cd <= 0.0 and _spend_stamina(SPELL_COST, stats):
		_do_spell(stats)

	if stamina_lock <= 0.0:
		stamina = minf(stats.max_stamina, stamina + STAMINA_REGEN * delta)


func _do_melee(stats: StatBlock) -> void:
	melee_timer = MELEE_TIME
	melee_cd = MELEE_COOLDOWN
	_melee_hits.clear()
	_melee_power = CombatResolver.player_melee_power(stats)
	if _weapon_visual:
		_weapon_visual.rotation_degrees = Vector3(52, 8, -12)
		var tween := create_tween()
		tween.tween_property(_weapon_visual, "rotation_degrees", WEAPON_REST_ROT, 0.18)


func _melee_tick() -> void:
	if _camera == null or not is_inside_tree():
		return
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	for collider in StrikeQuery.hits_in_arc(
			space, origin, forward, MELEE_RANGE, DD.MONSTER_LAYER, [get_rid()], MELEE_CONE_DEG
		):
		if collider == null or not (collider is Node):
			continue
		var id := (collider as Node).get_instance_id()
		if _melee_hits.has(id):
			continue
		if collider.has_method("receive_hit"):
			_melee_hits[id] = true
			collider.receive_hit(_melee_power, global_position, false)
			var vfx := CombatVfx.from_node(self)
			if vfx:
				vfx.sword_impact((collider as Node3D).global_position + Vector3(0, 0.9, 0), forward)


func _do_spell(stats: StatBlock) -> void:
	spell_cd = SPELL_COOLDOWN
	var origin := _camera.global_position + -_camera.global_transform.basis.z * 0.7
	var dir := -_camera.global_transform.basis.z
	var vfx := CombatVfx.from_node(self)
	if vfx:
		vfx.cast_flash(origin, &"fireball")
	var bolt := Projectile.new()
	bolt.setup(origin, dir, CombatResolver.player_spell_power(stats), 12.0, true, Color(1.0, 0.45, 0.15), &"fireball")
	get_parent().add_child(bolt)


func receive_hit(raw_damage: float, from: Vector3, already_mitigated: bool) -> void:
	if not alive:
		return
	var stats := GameSession.profile.total_stats()
	var dmg := raw_damage if already_mitigated else CombatResolver.mitigated_damage(raw_damage, stats.defense)
	if blocking:
		dmg = CombatResolver.apply_block(dmg, true)
		_spend_stamina(BLOCK_HIT_COST, stats)
	health = maxf(0.0, health - dmg)
	last_hit_from = from
	last_hit_amount = dmg
	_shake = minf(1.4, 0.35 + dmg / 28.0)
	if _hurt_player:
		_hurt_player.play()
	if _hit_player:
		_hit_player.play()
	GameSession.log_message.emit("-%s HP" % str(dmg), Color(1.0, 0.4, 0.35))
	took_hit.emit(dmg, from)
	if health <= 0.0:
		alive = false
		input_enabled = false
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


func _query_interactable() -> Interactable:
	if _camera == null or not is_inside_tree():
		return null
	var vp := get_viewport()
	var size := vp.get_visible_rect().size if vp else Vector2.ZERO
	var origin: Vector3
	var dir: Vector3
	if size.x >= 1.0 and size.y >= 1.0:
		var center := size * 0.5
		origin = _camera.project_ray_origin(center)
		dir = _camera.project_ray_normal(center)
	else:
		origin = _camera.global_position
		dir = -_camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	if space == null:
		return null
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * INTERACT_RANGE)
	q.collision_mask = DD.WORLD_LAYER | DD.INTERACT_LAYER
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.hit_from_inside = true
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var collider: Variant = hit.get("collider")
	if collider is Interactable:
		return collider as Interactable
	return null


func _try_interact() -> void:
	var target := _query_interactable()
	if target:
		target.try_use(self)


func _update_prompt() -> void:
	var text := ""
	var target := _query_interactable()
	if target and not target.used:
		if target.locked:
			text = "Sealed — defeat the boss"
		else:
			text = "E — %s" % target.prompt
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
