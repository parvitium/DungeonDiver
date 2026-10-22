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
	call_deferred("_enable_monitorable")


func _enable_monitorable() -> void:
	if is_inside_tree():
		monitorable = true


func try_use(by: Node) -> bool:
	if locked or used:
		return false
	if consume_on_use:
		used = true
	activated.emit(by)
	return true
