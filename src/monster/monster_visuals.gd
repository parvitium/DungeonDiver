class_name MonsterVisuals
extends RefCounted
## Maps monster ids to rigged GLB scenes and animation clip names.


const CAPSULE_RADIUS := 0.4
const CAPSULE_HEIGHT := 1.6

const CONFIG := {
	"skeleton": {
		"scene": "res://assets/models/monsters/pbr_skeleton.glb",
		"height": 1.7,
		"yaw": PI,
		"label_y": 1.95,
		"idle": "Idle",
		"walk": "Walk",
		"run": "Run",
		"attack": "Attack",
		"death": "Death",
	},
	"cave_wolf": {
		"scene": "res://assets/models/monsters/pbr_wolf.glb",
		"height": 1.05,
		"yaw": PI,
		"label_y": 1.2,
		"idle": "Idle",
		"walk": "Walk",
		"run": "Run",
		"attack": "Attack",
		"death": "Death",
	},
	"wraith": {
		"scene": "res://assets/models/monsters/pbr_skeleton.glb",
		"height": 1.75,
		"yaw": PI,
		"label_y": 2.05,
		"idle": "Idle",
		"walk": "Walk",
		"run": "Run",
		"attack": "Attack",
		"death": "Death",
		"style": "wraith",
		"hover": 0.22,
	},
	"lich": {
		"scene": "res://assets/models/monsters/pbr_lich.glb",
		"height": 1.85,
		"yaw": PI,
		"label_y": 2.15,
		"idle": "Idle",
		"walk": "Walk",
		"run": "Run",
		"attack": "Attack",
		"death": "Death",
	},
	"cave_troll": {
		"scene": "res://assets/models/monsters/pbr_troll.glb",
		"height": 2.15,
		"yaw": PI,
		"label_y": 2.35,
		"idle": "Idle",
		"walk": "Walk",
		"run": "Run",
		"attack": "Attack",
		"death": "Death",
	},
}


static func config_for(id: StringName) -> Dictionary:
	var key := String(id)
	if CONFIG.has(key):
		return CONFIG[key]
	return {}


static func attach(host: Node3D, def: MonsterDef) -> Dictionary:
	var info := {"root": null, "anim": null, "config": {}, "label_y": 1.85}
	var cfg: Dictionary = config_for(def.id if def else StringName())
	info["config"] = cfg
	if not cfg.is_empty():
		info["label_y"] = float(cfg.get("label_y", 1.85))
		var path := String(cfg.get("scene", ""))
		if ResourceLoader.exists(path):
			var packed := load(path)
			if packed is PackedScene:
				var model := (packed as PackedScene).instantiate() as Node3D
				model.name = "BodyVisual"
				model.rotation.y = float(cfg.get("yaw", 0.0))
				_strip_collision(model)
				host.add_child(model)
				info["anim"] = _find_anim(model)
				_hide_named(model, cfg.get("hide", []))
				_stylize(model, String(cfg.get("style", "")))
				Greybox.fit_height(model, float(cfg.get("height", 1.65)))
				model.position.y += float(cfg.get("hover", 0.0))
				info["root"] = model
				if info["anim"]:
					play(info, "idle", true)
				return info
	var fallback := Greybox.make_capsule_visual(0.38, 1.5, def.color if def else Color.RED)
	fallback.position = Vector3(0, 0.8, 0)
	fallback.scale = def.scale if def else Vector3.ONE
	host.add_child(fallback)
	info["root"] = fallback
	return info


static func play(info: Dictionary, kind: String, loop: bool) -> bool:
	var anim: AnimationPlayer = info.get("anim")
	if anim == null:
		return false
	var clip := resolve_clip(anim, info.get("config", {}), kind)
	if clip.is_empty():
		return false
	_apply_loop(anim, clip, loop)
	if anim.current_animation == clip and anim.is_playing():
		return true
	anim.play(clip)
	return true


static func _apply_loop(anim: AnimationPlayer, clip: String, loop: bool) -> void:
	if not anim.has_animation(clip):
		return
	var res: Animation = anim.get_animation(clip)
	if res == null:
		return
	res.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


static func resolve_clip(anim: AnimationPlayer, cfg: Dictionary, kind: String) -> String:
	var preferred := String(cfg.get(kind, ""))
	var names := anim.get_animation_list()
	if not preferred.is_empty():
		for n in names:
			if n == preferred or n.ends_with("/" + preferred) or n.ends_with("|" + preferred):
				return n
	var keys: PackedStringArray = PackedStringArray()
	match kind:
		"idle":
			keys = PackedStringArray(["idle", "flying_idle"])
		"walk":
			keys = PackedStringArray(["walk", "walking", "flying"])
		"run":
			keys = PackedStringArray(["run", "sprint", "gallop", "fast_flying"])
		"attack":
			keys = PackedStringArray(["attack", "punch", "headbutt", "melee", "chop"])
		"death":
			keys = PackedStringArray(["death", "die"])
		_:
			keys = PackedStringArray([kind])
	for n in names:
		var low := n.to_lower()
		for key in keys:
			if low.contains(key) and not low.contains("pose") and not low.contains("resurrect"):
				return n
	return ""


static func _hide_named(root: Node, names) -> void:
	if names == null:
		return
	for child in root.get_children():
		if names.has(child.name) and child is Node3D:
			(child as Node3D).visible = false
		_hide_named(child, names)


static func _stylize(root: Node, style: String) -> void:
	if style.is_empty():
		return
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var src: Material = mi.get_active_material(0)
		if src == null:
			src = mi.material_override
		if src is StandardMaterial3D:
			var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			match style:
				"wraith":
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color = Color(0.55, 0.82, 1.0, 0.38)
					mat.emission_enabled = true
					mat.emission = Color(0.32, 0.72, 1.0)
					mat.emission_energy_multiplier = 1.7
					mat.roughness = 0.18
					mat.metallic = 0.05
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				"lich":
					mat.albedo_color = Color(0.62, 0.42, 0.92)
					mat.emission_enabled = true
					mat.emission = Color(0.45, 0.18, 0.75)
					mat.emission_energy_multiplier = 0.55
					mat.roughness = 0.42
					mat.metallic = 0.18
				"bone":
					mat.roughness = 0.84
					mat.metallic = 0.06
			mi.material_override = mat
	for child in root.get_children():
		_stylize(child, style)


static func _find_anim(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_anim(child)
		if found:
			return found
	return null


static func _strip_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_strip_collision(child)
