Add `ItemDef` `.tres` files here. `example_relic.tres` (`ashen_circlet`) shows the format.

`ContentDB` only inserts a file if it `is ItemDef` and passes field checks (non-empty `id` + `display_name`, slot in range, rarity range, numeric `base_stats`). A `LootTable` dropped in this folder is ignored.

Extras that are not already on a loot table are appended to `mixed_drops` so they can drop in play.
