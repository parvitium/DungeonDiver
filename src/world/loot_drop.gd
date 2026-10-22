class_name LootDrop
extends Interactable

var item: ItemInstance


func setup(p_item: ItemInstance) -> void:
	item = p_item
	prompt = "Pick up %s" % item.full_name()
	consume_on_use = true
	var visual := Greybox.make_box(Vector3(0.45, 0.28, 0.45), DD.rarity_color(item.rarity), false)
	visual.position = Vector3(0, 0.2, 0)
	add_child(visual)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	add_child(shape)
	var glow := OmniLight3D.new()
	glow.light_color = DD.rarity_color(item.rarity)
	glow.light_energy = 0.8
	glow.omni_range = 2.4
	glow.position = Vector3(0, 0.4, 0)
	add_child(glow)
	activated.connect(_on_activated)


func _on_activated(_by: Node) -> void:
	if item != null:
		var drops: Array[ItemInstance] = []
		drops.append(item)
		GameSession.give_loot(drops)
	queue_free()
