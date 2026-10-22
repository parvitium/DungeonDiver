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
var _visual: Node3D
var _anim: AnimationPlayer
var _bob: float = 0.0


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
	var sy := def.scale.y if def else 1.0
	var sx := maxf(def.scale.x, def.scale.z) if def else 1.0
	shape.radius = 0.4 * sx
	shape.height = 1.7 * sy
	capsule.shape = shape
	capsule.position = Vector3(0, shape.height * 0.5, 0)
	add_child(capsule)

	_visual = _make_body()
	add_child(_visual)
	_anim = AssetLibrary.first_animation_player(_visual)
	AssetLibrary.play_if_has(_anim, "idle")

	if def and def.is_boss and _visual.get_node_or_null("Crown") == null and String(def.id) == "cave_troll":
		var crown := MeshFactory.visual(MeshFactory.beveled_box(Vector3(0.42, 0.1, 0.42), 0.02, 0.4), PBRLibrary.metal(), "Crown")
		crown.position = Vector3(0, 2.05 * (def.scale.y if def else 1.0), 0)
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
	label.position = Vector3(0, 1.85 * (def.scale.y if def else 1.0), 0)
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
	_update_visual(delta)
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
	if not AssetLibrary.play_if_has(_anim, "death"):
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.28)
		tween.tween_callback(queue_free)
		return
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(queue_free)


func _make_body() -> Node3D:
	var authored := AssetLibrary.instance(AssetLibrary.monster_path(def.id if def else &"skeleton"))
	if authored:
		authored.name = "BodyVisual"
		authored.scale = def.scale if def else Vector3.ONE
		_paint_creature(authored)
		return authored
	var fallback := Greybox.make_capsule_visual(0.38, 1.5, def.color if def else Color.RED)
	fallback.position = Vector3(0, 0.8, 0)
	fallback.scale = def.scale if def else Vector3.ONE
	return fallback


func _paint_creature(root: Node) -> void:
	_paint_named(root)


func _mat_for_part(part_name: String) -> StandardMaterial3D:
	var n := part_name.to_lower()
	if n.begins_with("glow") or n.begins_with("eye") or n.begins_with("orb") or n.begins_with("cavity"):
		if def and String(def.id) == "wraith":
			return PBRLibrary.emissive(Color(0.45, 0.82, 0.95), 2.4)
		if def and String(def.id) == "lich":
			return PBRLibrary.emissive(Color(0.62, 0.28, 0.95), 2.8)
		return PBRLibrary.emissive(Color(0.85, 0.2, 0.15), 1.8)
	if n.begins_with("armor") or n.begins_with("metal") or n.begins_with("sword") or n.begins_with("crown") or n.begins_with("helm"):
		return PBRLibrary.metal()
	if n.begins_with("wood") or n.begins_with("staff") or n.begins_with("club"):
		return PBRLibrary.wood()
	if n.begins_with("robe") or n.begins_with("cloth") or n.begins_with("hood") or n.begins_with("tatter"):
		if def and String(def.id) == "wraith":
			var ghost := PBRLibrary.emissive(Color(0.38, 0.68, 0.82), 0.55)
			ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost.albedo_color = Color(0.42, 0.68, 0.82, 0.48)
			return ghost
		return PBRLibrary.cloth(Color(0.18, 0.08, 0.24) if def and String(def.id) == "lich" else Color(0.22, 0.12, 0.10))
	if n.begins_with("fur") or n.begins_with("hide"):
		return PBRLibrary.tinted(PBRLibrary.wood(), Color(0.38, 0.26, 0.16))
	if n.begins_with("stone") or n.begins_with("rock"):
		return PBRLibrary.tinted(PBRLibrary.wall(&"cavern"), Color(0.40, 0.46, 0.34))
	if def and String(def.id) == "cave_troll" and (n.begins_with("bone") == false):
		return PBRLibrary.tinted(PBRLibrary.wall(&"cavern"), Color(0.36, 0.46, 0.30))
	if def and String(def.id) == "cave_wolf":
		return PBRLibrary.tinted(PBRLibrary.wood(), Color(0.40, 0.28, 0.18))
	return PBRLibrary.tinted(PBRLibrary.bone(), Color(0.90, 0.84, 0.70))


func _paint_named(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _mat_for_part(String(node.name))
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_paint_named(child)


func _update_visual(delta: float) -> void:
	if _visual == null:
		return
	match state:
		State.PATROL:
			AssetLibrary.play_if_has(_anim, "walk")
		State.CHASE:
			AssetLibrary.play_if_has(_anim, "walk")
		State.ATTACK:
			AssetLibrary.play_if_has(_anim, "attack")
		_:
			AssetLibrary.play_if_has(_anim, "idle")
	if _anim:
		return
	_bob += delta * (6.0 if state == State.CHASE else 3.0)
	var hop := 0.03 * sin(_bob) if state != State.ATTACK else 0.0
	_visual.position.y = 0.02 + hop


func _pick_patrol() -> void:
	var stream: GameRNG = GameSession.ai_rng if GameSession and GameSession.ai_rng else GameRNG.new(1)
	patrol_target = home + Vector3(
		stream.randf_range(-3.5, 3.5),
		0,
		stream.randf_range(-3.5, 3.5)
	)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
