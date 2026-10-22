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
	return t


static func _gear(id: String, slot: DD.EquipSlot, attack: float) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = id
	item.def_id = &"test"
	item.display_name = "Test"
	item.slot = slot
	item.stats = StatBlock.new(attack, 0, 0, 0, 0)
	return item
