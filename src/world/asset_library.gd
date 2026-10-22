class_name AssetLibrary
extends RefCounted
## Loads authored .glb visuals. Falls back to generated kit pieces.


static func instance(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is PackedScene:
		var node := (res as PackedScene).instantiate()
		if node is Node3D:
			return node
		node.free()
	return null


static func first_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := first_animation_player(child)
		if found:
			return found
	return null


static func play_if_has(anim: AnimationPlayer, clip: String) -> bool:
	if anim == null:
		return false
	if anim.has_animation(clip):
		if anim.current_animation != clip:
			anim.play(clip)
		return true
	var names := anim.get_animation_list()
	for name in names:
		if String(name).ends_with("/" + clip) or String(name) == clip:
			if anim.current_animation != name:
				anim.play(name)
			return true
	return false


static func monster_path(id: StringName) -> String:
	return "res://assets/meshes/monsters/%s.glb" % String(id)


static func weapon_path(kind: String) -> String:
	return "res://assets/meshes/weapons/%s.glb" % kind


static func prop_path(kind: String) -> String:
	return "res://assets/meshes/props/%s.glb" % kind


static func kit_path(kind: String) -> String:
	return "res://assets/meshes/kit/%s.glb" % kind
