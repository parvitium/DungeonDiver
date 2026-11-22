class_name TestInventory
extends RefCounted


static func run() -> DDTest:
	var t := DDTest.new("inventory")
	var inv := Inventory.new()
	var sword := _gear("s1", DD.EquipSlot.WEAPON, 5)
	var helm := _gear("h1", DD.EquipSlot.HEAD, 0)
	helm.stats.defense = 4
	inv.add_item(sword)
	inv.add_item(helm)
	t.assert_eq(inv.items.size(), 2, "bag size")
	t.assert_true(inv.equip(sword.instance_id), "equip sword")
	t.assert_eq(inv.items.size(), 1, "equipped leaves bag")
	t.assert_eq(inv.equipped_stats().attack, 5.0, "worn attack")
	t.assert_true(inv.equip(helm.instance_id), "equip helm")
	t.assert_eq(inv.equipped_stats().defense, 4.0, "worn defense")
	var sword2 := _gear("s2", DD.EquipSlot.WEAPON, 9)
	inv.add_item(sword2)
	t.assert_true(inv.equip(sword2.instance_id), "swap weapon")
	t.assert_eq(inv.equipped_stats().attack, 9.0, "new weapon stats")
	t.assert_eq(inv.items.size(), 1, "old weapon returned")
	t.assert_true(inv.unequip(DD.EquipSlot.HEAD), "unequip")
	t.assert_eq(inv.equipped_stats().defense, 0.0, "unequipped defense")

	var copy := Inventory.from_dict(inv.to_dict())
	t.assert_eq(copy.equipped_stats().attack, inv.equipped_stats().attack, "inventory save roundtrip")

	var profile := PlayerProfile.new()
	var before := profile.total_stats().attack
	var relic := _gear("atk", DD.EquipSlot.WEAPON, 7)
	profile.inventory.add_item(relic)
	t.assert_eq(profile.inventory.items.size(), 1, "picked-up item appears")
	t.assert_true(profile.inventory.equip(relic.instance_id), "equip relic")
	t.assert_eq(profile.total_stats().attack, before + 7.0, "equip changes stats")
	t.assert_true(profile.inventory.unequip(DD.EquipSlot.WEAPON), "unequip relic")
	t.assert_eq(profile.total_stats().attack, before, "unequip reverts stats")

	profile.current_health = 40.0
	var flask := ItemInstance.new()
	flask.instance_id = "potion1"
	flask.def_id = &"health_flask"
	flask.display_name = "Health Flask"
	flask.slot = DD.EquipSlot.CONSUMABLE
	flask.is_consumable = true
	flask.heal_amount = 40.0
	profile.inventory.add_item(flask)
	t.assert_true(profile.inventory.use_consumable(flask.instance_id, profile), "use potion")
	t.assert_eq(profile.current_health, 80.0, "potion use heals")
	t.assert_eq(profile.inventory.items.size(), 1, "potion consumed")
	t.assert_true(profile.inventory.discard("atk"), "discard bag item")
	t.assert_eq(profile.inventory.find("atk"), null, "discarded gone")
	return t


static func _gear(id: String, slot: DD.EquipSlot, attack: float) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = id
	item.def_id = &"test"
	item.display_name = "Test"
	item.slot = slot
	item.stats = StatBlock.new(attack, 0, 0, 0, 0)
	return item
