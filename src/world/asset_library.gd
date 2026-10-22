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
	var resolved := resolve_clip(anim, clip)
	if resolved.is_empty():
		return false
	var animation := anim.get_animation(resolved)
	if animation:
		if clip == "idle" or clip == "walk":
			animation.loop_mode = Animation.LOOP_LINEAR
		else:
			animation.loop_mode = Animation.LOOP_NONE
	if anim.current_animation != resolved:
		anim.play(resolved)
	return true


static func resolve_clip(anim: AnimationPlayer, clip: String) -> String:
	if anim == null:
		return ""
	if anim.has_animation(clip):
		return clip
	var needle := clip.to_lower()
	for name in anim.get_animation_list():
		var n := String(name).to_lower()
		if n == needle or n.ends_with("/" + needle) or n.ends_with("_" + needle) or n.begins_with(needle + "_"):
			return String(name)
	return ""


static func monster_path(id: StringName) -> String:
	return "res://assets/meshes/monsters/%s.glb" % String(id)


static func weapon_path(kind: String) -> String:
	return "res://assets/meshes/weapons/%s.glb" % kind


static func prop_path(kind: String) -> String:
	return "res://assets/meshes/props/%s.glb" % kind


static func kit_path(kind: String) -> String:
	return "res://assets/meshes/kit/%s.glb" % kind
