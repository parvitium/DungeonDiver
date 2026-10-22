extends Node
## Loads built-in catalog plus any extra resources dropped in res://data/.
## Extra .tres files are class-checked and field-validated before insert.

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
	_load_extra("res://data/items", items, &"item")
	_load_extra("res://data/monsters", monsters, &"monster")
	_load_extra("res://data/dungeons", dungeons, &"dungeon")
	_load_extra("res://data/loot_tables", loot_tables, &"loot_table")
	_offer_unlisted_items()


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


func item_is_on_a_table(item_id: StringName) -> bool:
	var key := String(item_id)
	for table in loot_tables.values():
		if table is LootTable:
			for listed in table.item_ids:
				if listed == key:
					return true
	return false


func accepts_extra(resource: Variant, kind: StringName) -> bool:
	match kind:
		&"item":
			return ItemDef.is_valid_extra(resource)
		&"monster":
			return MonsterDef.is_valid_extra(resource)
		&"dungeon":
			return DungeonTypeDef.is_valid_extra(resource)
		&"loot_table":
			return LootTable.is_valid_extra(resource)
		_:
			return false


func _load_extra(dir_path: String, dest: Dictionary, kind: StringName) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource := load("%s/%s" % [dir_path, file_name])
			if accepts_extra(resource, kind):
				dest[String(resource.id)] = resource
			elif resource != null:
				push_warning("Skipping %s/%s: not a valid %s" % [dir_path, file_name, String(kind)])
		file_name = dir.get_next()
	dir.list_dir_end()


func _offer_unlisted_items() -> void:
	var extras: PackedStringArray = []
	for item_id in items.keys():
		if not item_is_on_a_table(StringName(item_id)):
			extras.append(String(item_id))
	if extras.is_empty():
		return
	var table: LootTable = get_loot_table(&"mixed_drops")
	if table == null:
		return
	for extra_id in extras:
		table.item_ids.append(extra_id)
		table.weights.append(12.0)
