class_name DungeonGenerator
extends RefCounted

const DIRS := {
	"n": Vector2i(0, -1),
	"s": Vector2i(0, 1),
	"e": Vector2i(1, 0),
	"w": Vector2i(-1, 0),
}
static func generate(def: DungeonTypeDef, depth: int, seed_value: int) -> DungeonBlueprint:
	var rng := GameRNG.new(seed_value)
	var blueprint := DungeonBlueprint.new()
	blueprint.dungeon_id = def.id
	blueprint.depth = maxi(1, depth)
	blueprint.effective_tier = DD.effective_tier(def.base_tier, blueprint.depth)
	blueprint.seed_value = rng.seed_value

	var wanted := clampi(rng.randi_range(def.min_rooms, def.max_rooms), 4, 16)
	var cells: Dictionary = {}
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	cells[Vector2i.ZERO] = true

	while cells.size() < wanted and not frontier.is_empty():
		var index := rng.randi_range(0, frontier.size() - 1)
		var current: Vector2i = frontier[index]
		var keys := DIRS.keys()
		rng.shuffle(keys)
		var placed := false
		for key in keys:
			var next: Vector2i = current + DIRS[key]
			if cells.has(next):
				continue
			if absi(next.x) > 4 or absi(next.y) > 4:
				continue
			cells[next] = true
			frontier.append(next)
			placed = true
			break
		if not placed:
			frontier.remove_at(index)

	if cells.size() < 4:
		for extra in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)]:
			cells[extra] = true

	var start := Vector2i.ZERO
	var boss := _farthest(cells, start)
	blueprint.start_cell = start
	blueprint.boss_cell = boss

	for cell: Vector2i in cells.keys():
		var room := RoomSpec.new()
		room.cell = cell
		if cell == start:
			room.kind = DD.RoomKind.START
		elif cell == boss:
			room.kind = DD.RoomKind.BOSS
			room.has_exit = true
			room.monster_ids = PackedStringArray([String(def.boss_id)])
		else:
			room.kind = DD.RoomKind.COMBAT
			room.monster_ids = _roll_room_monsters(def, rng)
			room.has_chest = rng.randf() < def.chest_chance
			if room.has_chest:
				room.kind = DD.RoomKind.TREASURE
		for key in DIRS.keys():
			var neighbor: Vector2i = cell + DIRS[key]
			room.doors[key] = cells.has(neighbor)
		blueprint.rooms.append(room)

	return blueprint


static func _farthest(cells: Dictionary, start: Vector2i) -> Vector2i:
	var best := start
	var best_dist := -1
	for cell: Vector2i in cells.keys():
		var dist := absi(cell.x - start.x) + absi(cell.y - start.y)
		if dist > best_dist:
			best_dist = dist
			best = cell
	return best


static func _roll_room_monsters(def: DungeonTypeDef, rng: GameRNG) -> PackedStringArray:
	var count := rng.randi_range(1, 3)
	var ids := PackedStringArray()
	if def.monster_pool.is_empty():
		return ids
	for _i in count:
		ids.append(rng.pick_weighted_ids(def.monster_pool, def.monster_weights))
	return ids
