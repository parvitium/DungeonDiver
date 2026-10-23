class_name TestUI
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("ui")
	_pause_layout(t)
	_bestiary_layout(t)
	_resolutions(t)
	return t


static func _pause_layout(t: DDTest) -> void:
	var pause := _mount(load("res://src/ui/pause_panel.gd") as GDScript)
	t.assert_eq(pause.anchor_right, 1.0, "pause full-rect right")
	t.assert_eq(pause.anchor_bottom, 1.0, "pause full-rect bottom")
	t.assert_eq(pause.offset_left, 0.0, "pause not PRESET_CENTER left")
	t.assert_eq(pause.offset_top, 0.0, "pause not PRESET_CENTER top")
	var center := pause.get_node_or_null("Center")
	t.assert_true(center is CenterContainer, "pause uses CenterContainer")
	if center is CenterContainer:
		t.assert_eq((center as Control).anchor_right, 1.0, "pause center full-rect")
		t.assert_eq((center as Control).anchor_bottom, 1.0, "pause center full-rect bottom")
	var buttons := _buttons(pause)
	t.assert_true(buttons.size() >= 4, "pause has actions")
	if not buttons.is_empty():
		t.assert_eq(buttons[0].text, "Resume", "first chip is Resume")
	var labels: PackedStringArray = []
	for btn in buttons:
		labels.append(btn.text)
	t.assert_true("Resume" in labels, "Resume present")
	t.assert_true("Abandon dungeon" in labels, "Abandon is a separate option")
	t.assert_true(labels.find("Resume") < labels.find("Abandon dungeon"), "Resume before Abandon")
	t.assert_false(labels[0] == "Abandon dungeon", "clickable resume chip is not Abandon")
	pause.free()


static func _bestiary_layout(t: DDTest) -> void:
	var best := _mount(load("res://src/ui/bestiary_panel.gd") as GDScript)
	t.assert_eq(best.anchor_right, 1.0, "bestiary full-rect right")
	t.assert_eq(best.anchor_bottom, 1.0, "bestiary full-rect bottom")
	t.assert_eq(best.offset_left, 0.0, "bestiary not PRESET_CENTER left")
	t.assert_eq(best.offset_top, 0.0, "bestiary not PRESET_CENTER top")
	var center := best.get_node_or_null("Center")
	t.assert_true(center is CenterContainer, "bestiary uses CenterContainer")
	if center is CenterContainer:
		t.assert_eq((center as Control).anchor_right, 1.0, "bestiary center full-rect")
		var sheet := center.get_node_or_null("Sheet")
		t.assert_true(sheet is Control, "bestiary sheet")
		if sheet is Control:
			var min_size: Vector2 = (sheet as Control).custom_minimum_size
			t.assert_true(min_size.x <= 1280.0, "bestiary fits 720p width")
			t.assert_true(min_size.y <= 720.0, "bestiary fits 720p height")
	var labels: PackedStringArray = []
	for btn in _buttons(best):
		labels.append(btn.text)
	t.assert_true("Back" in labels, "bestiary has Back")
	best.free()


static func _resolutions(t: DDTest) -> void:
	var sizes: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]
	for size in sizes:
		_assert_fits(t, load("res://src/ui/pause_panel.gd") as GDScript, size, "pause")
		_assert_fits(t, load("res://src/ui/bestiary_panel.gd") as GDScript, size, "bestiary")


static func _assert_fits(t: DDTest, script: GDScript, size: Vector2, label: String) -> void:
	var overlay := _mount(script)
	var center := overlay.get_node_or_null("Center")
	t.assert_true(center is CenterContainer, "%s center at %dx%d" % [label, int(size.x), int(size.y)])
	if center:
		var sheet := center.get_node_or_null("Sheet")
		if sheet is Control:
			var min_size: Vector2 = (sheet as Control).custom_minimum_size
			t.assert_true(min_size.x <= size.x, "%s width fits %d" % [label, int(size.x)])
			t.assert_true(min_size.y <= size.y, "%s height fits %d" % [label, int(size.y)])
			var origin := (size - min_size) * 0.5
			t.assert_true(origin.x >= 0.0, "%s centered x at %d" % [label, int(size.x)])
			t.assert_true(origin.y >= 0.0, "%s centered y at %d" % [label, int(size.y)])
	overlay.free()


static func _mount(script: GDScript) -> Control:
	var overlay: Control = script.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	if overlay.get_node_or_null("Center") == null and overlay.has_method("refresh"):
		overlay.call("refresh")
	return overlay


static func _buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	_collect_buttons(node, out)
	return out


static func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button and node.name != "Settings":
		out.append(node)
	for child in node.get_children():
		if child.name == "Settings":
			continue
		_collect_buttons(child, out)
