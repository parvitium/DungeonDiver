class_name Monster
extends CharacterBody3D

signal died(monster: Monster)

enum State { PATROL, CHASE, WINDUP, ATTACK, DEAD }

const SEPARATION_RADIUS := 1.35
const SEPARATION_STRENGTH := 4.8
const SURROUND_RADIUS := 1.55
const AVOID_RADIUS := 0.55
const WINDUP_MIN := 0.32
const WINDUP_MAX := 0.55

var def: MonsterDef
var max_health: float = 40.0
var health: float = 40.0
var damage: float = 8.0
var state: State = State.PATROL
var attack_cd: float = 0.0
var patrol_target: Vector3 = Vector3.ZERO
var home: Vector3 = Vector3.ZERO
var entity_id: String = ""
var windup_timer: float = 0.0
var strike_landed: bool = false

var _agent: NavigationAgent3D
var _player: Node3D
var _visual: Node3D
var _visual_info: Dictionary = {}
var _anim_kind: String = ""
var _charge: OmniLight3D
var _charge_orb: MeshInstance3D
var _windup_sfx: AudioStreamPlayer3D


func setup(p_def: MonsterDef, effective_tier: int) -> void:
	def = p_def
	entity_id = GameSession.ai_rng.next_id("mob") if GameSession and GameSession.ai_rng else DD.new_id("mob")
	max_health = CombatResolver.scaled_monster_health(def.max_health, effective_tier)
	health = max_health
	damage = CombatResolver.scaled_monster_damage(def.damage, effective_tier)
	_build()


func _ready() -> void:
	add_to_group("monsters")
	collision_layer = DD.MONSTER_LAYER
	collision_mask = DD.WORLD_LAYER | DD.PLAYER_LAYER | DD.MONSTER_LAYER
	if def != null and _visual == null:
		_build()
	sync_home()


func sync_home() -> void:
	home = global_position
	_pick_patrol()


func _build() -> void:
	if get_node_or_null("Hurtbox") != null:
		return
	var cfg: Dictionary = MonsterVisuals.config_for(def.id if def else StringName())
	var radius := MonsterVisuals.capsule_radius_of(cfg)
	var height := MonsterVisuals.capsule_height_of(cfg)
	var capsule := CollisionShape3D.new()
	capsule.name = "Hurtbox"
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	capsule.shape = shape
	capsule.position = Vector3(0, height * 0.5, 0)
	add_child(capsule)

	_visual_info = MonsterVisuals.attach(self, def)
	_visual = _visual_info.get("root") as Node3D
	_anim_kind = "idle"

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.1
	_agent.avoidance_enabled = true
	_agent.use_3d_avoidance = true
	_agent.height = height
	_agent.radius = maxf(radius + 0.08, AVOID_RADIUS)
	_agent.neighbor_distance = 5.0
	_agent.max_neighbors = 10
	_agent.max_speed = def.move_speed if def else 3.0
	_agent.velocity_computed.connect(_on_avoidance_velocity)
	add_child(_agent)

	var label := Label3D.new()
	label.text = def.display_name if def else "Monster"
	label.position = Vector3(0, float(_visual_info.get("label_y", 1.85)), 0)
	label.font_size = 28
	label.modulate = Color(1, 0.9, 0.75)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	_windup_sfx = AudioStreamPlayer3D.new()
	_windup_sfx.stream = Sfx.attack_windup()
	_windup_sfx.volume_db = -2.0
	add_child(_windup_sfx)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or def == null:
		return
	_player = _find_player()
	attack_cd = maxf(0.0, attack_cd - delta)
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta

	_update_state()
	match state:
		State.PATROL:
			_hide_charge()
			_move_toward(patrol_target, def.move_speed * 0.55, delta)
			if global_position.distance_to(patrol_target) < 1.2:
				_pick_patrol()
		State.CHASE:
			_hide_charge()
			if _player:
				_agent.target_position = _surround_point()
				var next := _agent.get_next_path_position()
				if global_position.distance_to(next) < 0.15:
					next = _surround_point()
				_move_toward(next, def.move_speed, delta)
		State.WINDUP:
			_face(_player.global_position if _player else global_position + -global_transform.basis.z)
			_apply_planar(_separation_vector() * SEPARATION_STRENGTH * 0.35)
			_pulse_charge()
			windup_timer -= delta
			if windup_timer <= 0.0:
				_land_strike()
				state = State.ATTACK
				attack_cd = def.attack_cooldown
		State.ATTACK:
			_hide_charge()
			_apply_planar(_separation_vector() * SEPARATION_STRENGTH * 0.35)
			if _player:
				_face(_player.global_position)
			if attack_cd <= 0.0:
				state = State.CHASE
	_sync_locomotion_anim()
	move_and_slide()
	_pin_visual()


func _update_state() -> void:
	if state == State.WINDUP or state == State.DEAD:
		return
	if _player == null:
		state = State.PATROL
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= _attack_reach() and attack_cd <= 0.0 and state != State.ATTACK and _has_player_los():
		_begin_windup()
	elif _should_chase(dist):
		if state != State.ATTACK:
			state = State.CHASE
	elif state != State.ATTACK:
		state = State.PATROL


func _should_chase(dist: float) -> bool:
	if def == null:
		return false
	var limit := def.lose_range if state == State.CHASE else def.detect_range
	if dist > limit:
		return false
	return _has_player_los() or (dist <= def.detect_range and _can_hear_player())


func _has_player_los() -> bool:
	if _player == null or not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var origin := global_position + Vector3(0, _eye_y(), 0)
	var exclude: Array = [get_rid()]
	if _player is CollisionObject3D:
		exclude.append((_player as CollisionObject3D).get_rid())
	return StrikeQuery.has_los(space, origin, StrikeQuery.aim_point(_player), exclude)


func _can_hear_player() -> bool:
	if _agent == null or _player == null or not _agent.is_inside_tree():
		return false
	var map := _agent.get_navigation_map()
	if map == RID():
		return false
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	_agent.target_position = _player.global_position
	return _agent.is_target_reachable()


func _eye_y() -> float:
	return MonsterVisuals.eye_y_of(_visual_info.get("config", {}))


func _pin_visual() -> void:
	if _visual == null:
		return
	_visual.position.x = 0.0
	_visual.position.z = 0.0


func _attack_reach() -> float:
	if def.uses_ranged:
		return def.attack_range
	return minf(def.attack_range, StrikeQuery.MONSTER_MELEE_MAX)


func _begin_windup() -> void:
	if _player == null:
		_player = _find_player()
	state = State.WINDUP
	strike_landed = false
	windup_timer = _windup_duration()
	_set_anim("attack", false)
	if _windup_sfx:
		_windup_sfx.play()
	if def.uses_ranged:
		_show_charge()
		var vfx := CombatVfx.from_node(self)
		if vfx:
			vfx.cast_flash(global_position + Vector3(0, 1.2, 0), CombatVfx.projectile_kind_for(def.id))


func _windup_duration() -> float:
	var anim: AnimationPlayer = _visual_info.get("anim")
	if anim and anim.current_animation_length > 0.08:
		return clampf(anim.current_animation_length * 0.45, WINDUP_MIN, WINDUP_MAX)
	return 0.4


func _land_strike() -> void:
	if _player == null:
		_player = _find_player()
	if strike_landed or _player == null or state == State.DEAD:
		return
	strike_landed = true
	if def.uses_ranged:
		_fire_bolt()
		return
	_melee_connect()


func _melee_connect() -> void:
	if _player == null or not _player.has_method("receive_hit"):
		return
	if not is_inside_tree():
		return
	var origin := global_position + Vector3(0, _eye_y(), 0)
	var forward := (_player.global_position - global_position)
	var reach := _attack_reach()
	if not StrikeQuery.in_cone(origin, forward, StrikeQuery.aim_point(_player), reach, StrikeQuery.MELEE_CONE_DEG):
		return
	var space := get_world_3d().direct_space_state
	var exclude: Array = [get_rid()]
	if _player is CollisionObject3D:
		exclude.append((_player as CollisionObject3D).get_rid())
	if not StrikeQuery.has_los(space, origin, StrikeQuery.aim_point(_player), exclude):
		return
	_player.receive_hit(damage, global_position, false)


func _fire_bolt() -> void:
	if _player == null or not is_inside_tree():
		return
	var origin := global_position + Vector3(0, 1.25, 0.15)
	if _charge_orb:
		origin = _charge_orb.global_position
	var aim := StrikeQuery.aim_point(_player)
	var dir := aim - origin
	if dir.length() < 0.05:
		return
	var bolt := Projectile.new()
	var color := def.color.lightened(0.35) if def else Color(0.55, 0.85, 1.0)
	var speed := clampf(def.projectile_speed, 7.0, 11.0)
	var kind := CombatVfx.projectile_kind_for(def.id if def else &"wraith")
	bolt.setup(origin, dir, damage, speed, false, color, kind)
	get_parent().add_child(bolt)


func _show_charge() -> void:
	if _charge == null:
		_charge = OmniLight3D.new()
		_charge.light_color = Color(0.45, 0.85, 1.0)
		_charge.omni_range = 3.2
		_charge.position = Vector3(0.35, 1.15, -0.35)
		add_child(_charge)
	if _charge_orb == null:
		_charge_orb = MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		_charge_orb.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.9, 1.0, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.85, 1.0)
		mat.emission_energy_multiplier = 3.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_charge_orb.material_override = mat
		_charge_orb.position = Vector3(0.35, 1.15, -0.35)
		add_child(_charge_orb)
	_charge.visible = true
	_charge_orb.visible = true
	_charge.light_energy = 2.8


func _pulse_charge() -> void:
	if _charge and _charge.visible:
		_charge.light_energy = 2.2 + 1.6 * absf(sin(Time.get_ticks_msec() * 0.012))
	if _charge_orb and _charge_orb.visible:
		var s := 0.85 + 0.3 * absf(sin(Time.get_ticks_msec() * 0.012))
		_charge_orb.scale = Vector3(s, s, s)


func _hide_charge() -> void:
	if _charge:
		_charge.visible = false
	if _charge_orb:
		_charge_orb.visible = false


func _surround_point() -> Vector3:
	if _player == null:
		return global_position
	var h := absi(entity_id.hash())
	var ang := float(h % 6283) * 0.001
	return _player.global_position + Vector3(cos(ang), 0, sin(ang)) * SURROUND_RADIUS


func _separation_vector() -> Vector3:
	var push := Vector3.ZERO
	if not is_inside_tree():
		return push
	for n in get_tree().get_nodes_in_group("monsters"):
		if n == self or not (n is Monster):
			continue
		var other := n as Monster
		if other.state == State.DEAD:
			continue
		var offset := global_position - other.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist < 0.001:
			var h := absi(entity_id.hash())
			offset = Vector3(cos(float(h)), 0, sin(float(h)))
			dist = 0.001
		if dist < SEPARATION_RADIUS:
			var w := (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS
			push += offset.normalized() * w
	return push


func _on_avoidance_velocity(safe: Vector3) -> void:
	velocity.x = safe.x
	velocity.z = safe.z


func _apply_planar(vec: Vector3) -> void:
	velocity.x = vec.x
	velocity.z = vec.z


func _move_toward(target: Vector3, speed: float, _delta: float) -> void:
	var point := target
	if _agent and state == State.CHASE:
		point = _agent.get_next_path_position()
	var offset := point - global_position
	offset.y = 0
	var desired := Vector3.ZERO
	if offset.length() > 0.05:
		offset = offset.normalized()
		desired = offset * speed
		_face(global_position + offset)
	desired += _separation_vector() * SEPARATION_STRENGTH
	if _agent and _agent.avoidance_enabled:
		_agent.max_speed = maxf(speed, 0.1)
		_agent.set_velocity(desired)
	else:
		velocity.x = desired.x
		velocity.z = desired.z


func _face(point: Vector3) -> void:
	var look := point
	look.y = global_position.y
	if look.distance_to(global_position) > 0.05:
		look_at(look, Vector3.UP)


func receive_hit(raw_damage: float, from: Vector3, already_mitigated: bool) -> void:
	if state == State.DEAD:
		return
	var dmg := raw_damage if already_mitigated else CombatResolver.mitigated_damage(raw_damage, 4.0)
	health -= dmg
	var push := global_position - from
	push.y = 0
	if push.length() > 0.01:
		global_position += push.normalized() * 0.25
	if _player and state != State.WINDUP:
		state = State.CHASE
	var vfx := CombatVfx.from_node(self)
	if vfx and def:
		var mat := CombatVfx.material_for(def.id)
		var toward := global_position - from
		vfx.hit(global_position + Vector3(0, 0.9, 0), toward, mat)
		vfx.flash_enemy(self)
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	_hide_charge()
	collision_layer = 0
	died.emit(self)
	var mat := CombatVfx.material_for(def.id if def else &"")
	var vfx := CombatVfx.from_node(self)
	if vfx:
		vfx.death(global_position, mat, self)
	if mat == &"bone":
		if _visual:
			_visual.visible = false
		if is_inside_tree():
			get_tree().create_timer(0.2).timeout.connect(queue_free)
		else:
			queue_free()
		return
	if _set_anim("death", false):
		var anim: AnimationPlayer = _visual_info.get("anim")
		var wait := 1.4
		if anim and anim.current_animation_length > 0.05:
			wait = anim.current_animation_length + 0.2
		if is_inside_tree():
			get_tree().create_timer(wait).timeout.connect(queue_free)
		else:
			queue_free()
	else:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.25)
		tween.tween_callback(queue_free)


func _sync_locomotion_anim() -> void:
	if state == State.DEAD:
		return
	if state == State.WINDUP or state == State.ATTACK:
		var anim: AnimationPlayer = _visual_info.get("anim")
		if anim and not anim.is_playing():
			_set_anim("idle", true)
		return
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	if speed > 2.4 and state == State.CHASE:
		_set_anim("run", true)
	elif speed > 0.35:
		_set_anim("walk", true)
	else:
		_set_anim("idle", true)


func _set_anim(kind: String, loop: bool) -> bool:
	if kind == _anim_kind and kind != "attack":
		return _visual_info.get("anim") != null
	if MonsterVisuals.play(_visual_info, kind, loop):
		_anim_kind = kind
		return true
	return false


func _pick_patrol() -> void:
	var stream: GameRNG = GameSession.ai_rng if GameSession and GameSession.ai_rng else GameRNG.new(1)
	patrol_target = home + Vector3(
		stream.randf_range(-3.5, 3.5),
		0,
		stream.randf_range(-3.5, 3.5)
	)


func _find_player() -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
