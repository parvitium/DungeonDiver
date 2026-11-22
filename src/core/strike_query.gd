class_name StrikeQuery
extends RefCounted
## Shared melee reach rules for the player sword and monster attacks.


const MELEE_RANGE := 2.0
const MELEE_CONE_DEG := 100.0
const MONSTER_MELEE_MAX := 2.2
const INTERACT_RANGE := 2.5
const CHEST_HEIGHT := 0.85


static func planar_distance(a: Vector3, b: Vector3) -> float:
	var d := a - b
	d.y = 0.0
	return d.length()


static func in_cone(origin: Vector3, forward: Vector3, target: Vector3, range_m: float, cone_deg: float = MELEE_CONE_DEG) -> bool:
	var to := target - origin
	to.y = 0.0
	var dist := to.length()
	if dist <= 0.35:
		return true
	if dist > range_m:
		return false
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length() < 0.01:
		return true
	return fwd.normalized().angle_to(to.normalized()) <= deg_to_rad(cone_deg * 0.5)


static func has_los(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array) -> bool:
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = DD.WORLD_LAYER
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	return hit.is_empty()


static func aim_point(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return node.global_position + Vector3(0.0, 0.8, 0.0)


static func collect_bodies(
		space: PhysicsDirectSpaceState3D,
		origin: Vector3,
		radius: float,
		mask: int,
		exclude: Array
	) -> Array:
	if space == null:
		return []
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = exclude
	return space.intersect_shape(params, 16)


static func hits_in_arc(
		space: PhysicsDirectSpaceState3D,
		origin: Vector3,
		forward: Vector3,
		range_m: float,
		mask: int,
		exclude: Array,
		cone_deg: float = MELEE_CONE_DEG
	) -> Array:
	var out: Array = []
	for hit in collect_bodies(space, origin, range_m, mask, exclude):
		var collider: Variant = hit.get("collider")
		if collider == null or not (collider is Node3D):
			continue
		var node := collider as Node3D
		var aim := aim_point(node)
		if not in_cone(origin, forward, aim, range_m, cone_deg):
			continue
		var extra: Array = exclude.duplicate()
		if collider is CollisionObject3D:
			extra.append((collider as CollisionObject3D).get_rid())
		if not has_los(space, origin, aim, extra):
			continue
		out.append(collider)
	return out
