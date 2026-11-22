class_name Projectile
extends Area3D
## Visible, wall-blocked bolt. Mask is set in setup() before entering the tree
## so enemy orbs cannot immediately collide with their caster.

signal impact(at: Vector3)

var velocity: Vector3 = Vector3.ZERO
var damage: float = 8.0
var lifetime: float = 3.2
var source_is_player: bool = true
var attacker_stats: StatBlock = StatBlock.new()
var kind: StringName = &"bolt"
var _spent: bool = false


func setup(
		from: Vector3,
		direction: Vector3,
		p_damage: float,
		speed: float,
		from_player: bool,
		color: Color,
		p_kind: StringName = &"bolt"
	) -> void:
	source_is_player = from_player
	kind = p_kind
	collision_layer = DD.PROJECTILE_LAYER
	if source_is_player:
		collision_mask = DD.MONSTER_LAYER | DD.WORLD_LAYER
	else:
		collision_mask = DD.PLAYER_LAYER | DD.WORLD_LAYER
	monitorable = false
	monitoring = true
	damage = p_damage
	velocity = direction.normalized() * speed
	CombatVfx.dress_projectile(self, kind, color)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.2
	shape.shape = sphere_shape
	add_child(shape)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	# setup() runs before add_child, so use local transform (global_* needs a tree).
	transform.origin = from
	if direction.length() > 0.01:
		var dir := direction.normalized()
		var up := Vector3.UP
		if absf(dir.dot(up)) > 0.98:
			up = Vector3.RIGHT
		transform.basis = Basis.looking_at(dir, up)
		transform.origin = from


func _physics_process(delta: float) -> void:
	if _spent:
		return
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	var hits_target := false
	if source_is_player and body.has_method("receive_hit") and not (body.is_in_group("player")):
		hits_target = true
	elif not source_is_player and body.has_method("receive_hit") and body.is_in_group("player"):
		hits_target = true
	if hits_target:
		_spent = true
		body.receive_hit(damage, global_position, false)
		_burst()
		return
	if body is StaticBody3D:
		_spent = true
		var vfx := CombatVfx.from_node(self)
		if vfx:
			vfx.hit(global_position, -velocity, &"stone")
		_burst()


func _burst() -> void:
	impact.emit(global_position)
	monitoring = false
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.85, 0.95, 1.0)
	flash.light_energy = 6.0
	flash.omni_range = 5.0
	add_child(flash)
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = Sfx.flesh_hit()
	sfx.volume_db = -4.0
	sfx.bus = "Master"
	add_child(sfx)
	sfx.play()
	velocity = Vector3.ZERO
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(flash, "light_energy", 0.0, 0.18)
		tween.tween_callback(queue_free)
	else:
		queue_free()
