class_name Interactable
extends Area3D

signal activated(by: Node)

@export var prompt: String = "Interact"
@export var locked: bool = false
@export var consume_on_use: bool = false

var used: bool = false


func _ready() -> void:
	collision_layer = DD.INTERACT_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func try_use(by: Node) -> bool:
	if locked or used:
		return false
	if consume_on_use:
		used = true
	activated.emit(by)
	return true


func cover_visual(visual: Node3D, pad: Vector3 = Vector3(0.18, 0.2, 0.18)) -> void:
	if visual == null:
		return
	var local := Greybox.visual_aabb(visual)
	var aabb: AABB = visual.transform * local
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if aabb.size.length() < 0.05:
		box.size = Vector3(1.05, 0.9, 0.85)
		col.position = Vector3(0, 0.4, 0)
	else:
		box.size = aabb.size + pad
		col.position = aabb.get_center()
	col.shape = box
	add_child(col)
