extends Node
## Loads built-in catalog plus any extra resources dropped in res://data/.

var items: Dictionary = {}
var monsters: Dictionary = {}
var dungeons: Dictionary = {}
var loot_tables: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	items.clear()
	monsters.clear()
	dungeons.clear()
	loot_tables.clear()
	for def in Catalog.all_items():
		items[String(def.id)] = def
	for def in Catalog.all_monsters():
		monsters[String(def.id)] = def
	for def in Catalog.all_dungeons():
		dungeons[String(def.id)] = def
	for def in Catalog.all_loot_tables():
		loot_tables[String(def.id)] = def
	_load_extra("res://data/items", items)
	_load_extra("res://data/monsters", monsters)
	_load_extra("res://data/dungeons", dungeons)
	_load_extra("res://data/loot_tables", loot_tables)


func get_item(id: StringName) -> ItemDef:
	return items.get(String(id), null)


func get_monster(id: StringName) -> MonsterDef:
	return monsters.get(String(id), null)


func get_dungeon(id: StringName) -> DungeonTypeDef:
	return dungeons.get(String(id), null)


func get_loot_table(id: StringName) -> LootTable:
	return loot_tables.get(String(id), null)


func item_ids() -> PackedStringArray:
	return PackedStringArray(items.keys())


func monster_ids() -> PackedStringArray:
	var ids := PackedStringArray(monsters.keys())
	ids.sort()
	return ids


func dungeon_ids() -> PackedStringArray:
	var ids := PackedStringArray(dungeons.keys())
	ids.sort()
	return ids


func _load_extra(dir_path: String, dest: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource := load("%s/%s" % [dir_path, file_name])
			if resource != null and resource.get("id") != null:
				dest[String(resource.id)] = resource
		file_name = dir.get_next()
	dir.list_dir_end()
