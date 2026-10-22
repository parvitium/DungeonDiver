class_name Projectile
extends Area3D

var velocity: Vector3 = Vector3.ZERO
var damage: float = 8.0
var lifetime: float = 2.2
var source_is_player: bool = true
var attacker_stats: StatBlock = StatBlock.new()


func _ready() -> void:
	collision_layer = DD.PROJECTILE_LAYER
	if source_is_player:
		collision_mask = DD.MONSTER_LAYER | DD.WORLD_LAYER
	else:
		collision_mask = DD.PLAYER_LAYER | DD.WORLD_LAYER
	body_entered.connect(_on_body_entered)
	monitoring = true


func setup(from: Vector3, direction: Vector3, p_damage: float, speed: float, from_player: bool, color: Color) -> void:
	global_position = from
	velocity = direction.normalized() * speed
	damage = p_damage
	source_is_player = from_player
	var visual := Greybox.make_box(Vector3(0.18, 0.18, 0.45), color, false)
	add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.22, 0.22, 0.5)
	shape.shape = box
	add_child(shape)
	var target := from + direction
	if not is_zero_approx(direction.normalized().cross(Vector3.UP).length()):
		look_at(target, Vector3.UP)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if source_is_player and body.has_method("receive_hit"):
		body.receive_hit(damage, global_position, false)
		queue_free()
	elif not source_is_player and body.has_method("receive_hit"):
		body.receive_hit(damage, global_position, false)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
