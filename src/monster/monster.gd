class_name Monster
extends CharacterBody3D

signal died(monster: Monster)

enum State { PATROL, CHASE, ATTACK, DEAD }

var def: MonsterDef
var max_health: float = 40.0
var health: float = 40.0
var damage: float = 8.0
var state: State = State.PATROL
var attack_cd: float = 0.0
var patrol_target: Vector3 = Vector3.ZERO
var home: Vector3 = Vector3.ZERO
var entity_id: String = ""

var _agent: NavigationAgent3D
var _player: Node3D
var _visual: MeshInstance3D


func setup(p_def: MonsterDef, effective_tier: int) -> void:
	def = p_def
	entity_id = GameSession.rng.next_id("mob") if GameSession and GameSession.rng else DD.new_id("mob")
	max_health = CombatResolver.scaled_monster_health(def.max_health, effective_tier)
	health = max_health
	damage = CombatResolver.scaled_monster_damage(def.damage, effective_tier)
	_build()


func _ready() -> void:
	add_to_group("monsters")
	collision_layer = DD.MONSTER_LAYER
	collision_mask = DD.WORLD_LAYER | DD.PLAYER_LAYER
	if def != null and _visual == null:
		_build()
	sync_home()


func sync_home() -> void:
	home = global_position
	_pick_patrol()


func _build() -> void:
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	capsule.shape = shape
	capsule.position = Vector3(0, 0.8, 0)
	add_child(capsule)

	_visual = Greybox.make_capsule_visual(0.38, 1.5, def.color if def else Color.RED)
	_visual.position = Vector3(0, 0.8, 0)
	_visual.scale = def.scale if def else Vector3.ONE
	add_child(_visual)

	if def and def.is_boss:
		var crown := Greybox.make_box(Vector3(0.7, 0.18, 0.7), Color(0.95, 0.75, 0.2), false)
		crown.position = Vector3(0, 1.7, 0)
		add_child(crown)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.1
	_agent.avoidance_enabled = false
	_agent.height = 1.6
	_agent.radius = 0.4
	add_child(_agent)

	var label := Label3D.new()
	label.text = def.display_name if def else "Monster"
	label.position = Vector3(0, 1.85, 0)
	label.font_size = 28
	label.modulate = Color(1, 0.9, 0.75)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


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
			_move_toward(patrol_target, def.move_speed * 0.55, delta)
			if global_position.distance_to(patrol_target) < 1.2:
				_pick_patrol()
		State.CHASE:
			if _player:
				_agent.target_position = _player.global_position
				var next := _agent.get_next_path_position()
				if global_position.distance_to(next) < 0.15:
					next = _player.global_position
				_move_toward(next, def.move_speed, delta)
		State.ATTACK:
			velocity.x = 0
			velocity.z = 0
			if _player:
				_face(_player.global_position)
				if attack_cd <= 0.0:
					_attack()
	move_and_slide()


func _update_state() -> void:
	if _player == null:
		state = State.PATROL
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= def.attack_range:
		state = State.ATTACK
	elif dist <= def.detect_range or (state == State.CHASE and dist <= def.lose_range):
		state = State.CHASE
	else:
		state = State.PATROL


func _move_toward(target: Vector3, speed: float, _delta: float) -> void:
	var point := target
	if _agent and state == State.CHASE:
		point = _agent.get_next_path_position()
	var offset := point - global_position
	offset.y = 0
	if offset.length() > 0.05:
		offset = offset.normalized()
		velocity.x = offset.x * speed
		velocity.z = offset.z * speed
		_face(global_position + offset)
	else:
		velocity.x = 0
		velocity.z = 0


func _face(point: Vector3) -> void:
	var look := point
	look.y = global_position.y
	if look.distance_to(global_position) > 0.05:
		look_at(look, Vector3.UP)


func _attack() -> void:
	attack_cd = def.attack_cooldown
	if def.uses_ranged:
		var bolt := Projectile.new()
		var origin := global_position + Vector3(0, 1.2, 0)
		var dir := (_player.global_position + Vector3(0, 1.2, 0)) - origin
		get_parent().add_child(bolt)
		bolt.setup(origin, dir, damage, def.projectile_speed, false, def.color.lightened(0.2))
	elif _player and _player.has_method("receive_hit"):
		_player.receive_hit(damage, global_position, false)


func receive_hit(raw_damage: float, from: Vector3, already_mitigated: bool) -> void:
	if state == State.DEAD:
		return
	var dmg := raw_damage if already_mitigated else CombatResolver.mitigated_damage(raw_damage, 4.0)
	health -= dmg
	var push := global_position - from
	push.y = 0
	if push.length() > 0.01:
		global_position += push.normalized() * 0.25
	if _player:
		state = State.CHASE
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.25)
	tween.tween_callback(queue_free)


func _pick_patrol() -> void:
	var session_rng: GameRNG = GameSession.rng if GameSession and GameSession.rng else GameRNG.new(1)
	patrol_target = home + Vector3(
		session_rng.randf_range(-3.5, 3.5),
		0,
		session_rng.randf_range(-3.5, 3.5)
	)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
