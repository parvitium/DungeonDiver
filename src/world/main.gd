extends Node


func _ready() -> void:
	change_scene.call_deferred()


func change_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
