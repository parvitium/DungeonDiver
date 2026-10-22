class_name TestSave
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("save")
	var profile := PlayerProfile.new()
	var item := ItemInstance.new()
	item.instance_id = "keep"
	item.def_id = &"rusty_sword"
	item.display_name = "Rusty Sword"
	item.slot = DD.EquipSlot.WEAPON
	item.rarity = DD.Rarity.RARE
	item.item_level = 2
	item.stats = StatBlock.new(8, 0, 0, 0, 0)
	profile.inventory.add_item(item)
	profile.inventory.equip("keep")
	profile.progression.record_kill(&"wraith")
	profile.progression.record_clear(&"cavern", 2)
	profile.current_health = 77

	var payload := SaveCodec.payload_from_profile(profile)
	t.assert_eq(int(payload.get("version", 0)), DD.SAVE_VERSION, "version")
	var loaded := SaveCodec.profile_from_payload(payload)
	t.assert_eq(loaded.current_health, 77.0, "health restored")
	t.assert_eq(loaded.progression.kills_of(&"wraith"), 1, "bestiary restored")
	t.assert_eq(loaded.progression.highest_clear(&"cavern"), 2, "dungeon log restored")
	t.assert_eq(loaded.inventory.equipped_stats().attack, 8.0, "gear restored")
	t.assert_eq(loaded.inventory.equipped[DD.EquipSlot.WEAPON].rarity, DD.Rarity.RARE, "rarity restored")
	return t
