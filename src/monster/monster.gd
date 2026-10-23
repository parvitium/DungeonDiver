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
var _hit_lock: float = 0.0
var _hp_timer: float = 0.0
var _hp_root: Node3D
var _hp_fill: MeshInstance3D


func setup(p_def: MonsterDef, effective_tier: int) -> void:
	def = p_def
	var ai := _session_ai_rng()
	entity_id = ai.next_id("mob") if ai else DD.new_id("mob")
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
	_align_visual_forward(_visual)
	_ground_visual(_visual)
	_anim = AssetLibrary.first_animation_player(_visual)
	AssetLibrary.play_if_has(_anim, "idle")

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.1
	_agent.avoidance_enabled = false
	_agent.height = 1.6
	_agent.radius = 0.4
	add_child(_agent)

	_build_health_bar()


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
		_hp_timer = maxf(_hp_timer, 0.4)
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
	var origin := global_position if is_inside_tree() else position
	var push := origin - from
	push.y = 0
	if push.length() > 0.01:
		var knock := push.normalized() * 0.25
		if is_inside_tree():
			global_position += knock
		else:
			position += knock
	if _player:
		state = State.CHASE
	_hit_lock = 0.38
	_hp_timer = 2.2
	_refresh_health_bar()
	AssetLibrary.play_if_has(_anim, "hit")
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
	var hold := 1.45
	var clip := AssetLibrary.resolve_clip(_anim, "death")
	if not clip.is_empty():
		var animation := _anim.get_animation(clip)
		if animation:
			hold = maxf(animation.length + 0.35, 1.45)
			_anim.seek(0.0, true)
			_anim.play(clip)
	var timer := get_tree().create_timer(hold)
	timer.timeout.connect(queue_free)


func _make_body() -> Node3D:
	var authored := AssetLibrary.instance(AssetLibrary.monster_path(def.id if def else &"skeleton"))
	if authored:
		authored.name = "BodyVisual"
		var uniform := def.scale.y if def else 1.0
		authored.scale = Vector3.ONE * uniform
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
			return PBRLibrary.emissive(Color(0.62, 0.28, 0.95), 3.2)
		return PBRLibrary.emissive(Color(0.85, 0.2, 0.15), 1.8)
	if n.begins_with("armor") or n.begins_with("metal") or n.begins_with("sword") or n.begins_with("crown") or n.begins_with("helm"):
		return PBRLibrary.metal()
	if n.begins_with("wood") or n.begins_with("staff") or n.begins_with("club"):
		return PBRLibrary.wood()
	if n.begins_with("cloth"):
		var fringe_color := Color(0.62, 0.64, 0.66, 1.0)
		if def and String(def.id) == "lich":
			fringe_color = Color(0.22, 0.10, 0.28)
		elif def == null or String(def.id) != "wraith":
			fringe_color = Color(0.28, 0.16, 0.10)
		return PBRLibrary.tattered_cloth(fringe_color)
	if n.begins_with("robe") or n.begins_with("hood") or n.begins_with("tatter") or n.begins_with("loin"):
		if def and String(def.id) == "wraith":
			var ghost := PBRLibrary.cloth(Color(0.68, 0.72, 0.74, 0.84))
			ghost = ghost.duplicate() as StandardMaterial3D
			ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost.albedo_color = Color(0.72, 0.74, 0.76, 0.92)
			ghost.emission_enabled = true
			ghost.emission = Color(0.16, 0.20, 0.22)
			ghost.emission_energy_multiplier = 0.08
			ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
			return ghost
		return PBRLibrary.cloth(Color(0.22, 0.10, 0.28) if def and String(def.id) == "lich" else Color(0.28, 0.16, 0.10))
	if n.begins_with("fur_shell") or n.begins_with("fur_card"):
		return PBRLibrary.fur_card()
	if n.begins_with("fur"):
		return PBRLibrary.fur()
	if n.begins_with("skin") or n.begins_with("wart") or n.begins_with("scar"):
		return PBRLibrary.skin()
	if n.begins_with("hide"):
		return PBRLibrary.tinted(PBRLibrary.skin(), Color(0.48, 0.56, 0.34))
	if n.begins_with("stone") or n.begins_with("rock"):
		return PBRLibrary.tinted(PBRLibrary.wall(&"cavern"), Color(0.40, 0.46, 0.34))
	if def and String(def.id) == "cave_troll" and (n.begins_with("bone") == false):
		return PBRLibrary.skin()
	if def and String(def.id) == "cave_wolf":
		return PBRLibrary.fur()
	return PBRLibrary.tinted(PBRLibrary.bone(), Color(0.90, 0.84, 0.70))


func _paint_named(node: Node) -> void:
	if String(node.name) in ["HealthBar", "CaptureFill", "HealthBarBg", "HealthBarFill"]:
		return
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _mat_for_part(String(node.name))
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_attach_orb_glow(node as MeshInstance3D)
	for child in node.get_children():
		_paint_named(child)


func _attach_orb_glow(mi: MeshInstance3D) -> void:
	var n := String(mi.name).to_lower()
	if not n.begins_with("glow"):
		return
	if mi.get_node_or_null("OrbGlow") != null:
		return
	var lamp := OmniLight3D.new()
	lamp.name = "OrbGlow"
	lamp.light_color = Color(0.62, 0.28, 0.95) if def and String(def.id) == "lich" else Color(0.45, 0.82, 0.95)
	lamp.light_energy = 3.6
	lamp.omni_range = 2.4
	lamp.omni_attenuation = 1.1
	lamp.shadow_enabled = false
	mi.add_child(lamp)


func _update_visual(delta: float) -> void:
	if _hp_timer > 0.0:
		_hp_timer = maxf(0.0, _hp_timer - delta)
		_refresh_health_bar()
	if _visual == null:
		return
	if _hit_lock > 0.0:
		_hit_lock = maxf(0.0, _hit_lock - delta)
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
	var stream: GameRNG = _session_ai_rng()
	if stream == null:
		stream = GameRNG.new(1)
	patrol_target = home + Vector3(
		stream.randf_range(-3.5, 3.5),
		0,
		stream.randf_range(-3.5, 3.5)
	)


func _session_ai_rng() -> GameRNG:
	# Node lookup so this class_name compiles under `godot -s` before autoload names exist.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var session := tree.root.get_node_or_null("GameSession")
	if session == null:
		return null
	var rng: Variant = session.get("ai_rng")
	return rng as GameRNG if rng is GameRNG else null


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]


func _build_health_bar() -> void:
	_hp_root = Node3D.new()
	_hp_root.name = "HealthBar"
	_hp_root.visible = false
	var height := 1.82 * (def.scale.y if def else 1.0)
	if _visual:
		var aabb := _local_aabb(_visual)
		if aabb.size.y >= 0.3 and aabb.size.y <= 3.6:
			height = aabb.position.y + aabb.size.y + 0.12
	height = clampf(height, 0.7, 3.2)
	_hp_root.position = Vector3(0, height, 0)
	add_child(_hp_root)
	var bg := MeshInstance3D.new()
	bg.name = "HealthBarBg"
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(0.55, 0.055)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.08, 0.06, 0.05, 0.7)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	bg.material_override = bg_mat
	_hp_root.add_child(bg)
	_hp_fill = MeshInstance3D.new()
	_hp_fill.name = "HealthBarFill"
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.52, 0.038)
	_hp_fill.mesh = fill_mesh
	_hp_fill.position = Vector3(0, 0, 0.002)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.72, 0.18, 0.16, 0.9)
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.no_depth_test = true
	_hp_fill.material_override = fill_mat
	_hp_root.add_child(_hp_fill)


func _refresh_health_bar() -> void:
	if _hp_root == null:
		return
	_hp_root.visible = _hp_timer > 0.0 and state != State.DEAD
	if _hp_fill == null:
		return
	var ratio := clampf(health / maxf(1.0, max_health), 0.0, 1.0)
	_hp_fill.scale = Vector3(ratio, 1.0, 1.0)
	_hp_fill.position.x = -0.26 * (1.0 - ratio)


func _align_visual_forward(root: Node3D) -> void:
	# Godot look_at aims local -Z at the player. If the authored face sits on +Z, spin it.
	var face_z := _face_marker_z(root)
	if face_z > 0.04:
		root.rotate_y(PI)


func _face_marker_z(root: Node) -> float:
	var total := 0.0
	var count := 0
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		var n := String(node.name).to_lower()
		if node is MeshInstance3D and (n.contains("eye") or n.contains("snout") or n.contains("tusk") or n.begins_with("hood") or n.contains("cavity_eye")):
			var mi := node as MeshInstance3D
			var xf := _relative_xform(root, mi)
			total += (xf * mi.get_aabb().get_center()).z
			count += 1
		for child in node.get_children():
			nodes.append(child)
	if count == 0:
		return 0.0
	return total / float(count)


func _ground_visual(root: Node3D) -> void:
	var aabb := _local_aabb(root)
	# Authored glbs are already feet-on-floor. Skip wild unskinned AABBs (the
	# wolf's 36x bind-pose box used to launch the mesh to y≈39).
	if aabb.size.y < 0.2 or aabb.size.y > 3.6:
		return
	var bottom := aabb.position.y * root.scale.y
	if absf(bottom) <= 0.05:
		return
	if absf(bottom) > 1.25:
		return
	root.position.y -= bottom / maxf(0.01, root.scale.y)


func _local_aabb(root: Node) -> AABB:
	var points: Array = []
	_collect_mesh_points(root, root, points)
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for p in points:
		result = result.expand(p)
	return result


func _collect_mesh_points(root: Node, node: Node, points: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var xf := _relative_xform(root, mi)
		var local := mi.get_aabb()
		for i in 8:
			points.append(xf * local.get_endpoint(i))
	for child in node.get_children():
		_collect_mesh_points(root, child, points)


func _relative_xform(root: Node, node: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
