# DungeonDiver

First-person fantasy dungeon explorer. Fight monsters, take their gear, and keep going until every dungeon type and every monster type is in the book.

This repository is a **playable vertical-slice prototype** in **Godot 4.7**. The landing screen is a cinematic dungeon hall. Rooms use a PBR modular kit (Poly Haven CC0 textures + Blender-authored meshes) with swap sockets left intact. Co-op is designed for, not shipped — see [`docs/multiplayer-plan.md`](docs/multiplayer-plan.md).

## Requirements

- [Godot 4.7.x](https://godotengine.org/download/linux/) (4.7.2 used in CI)
- No paid assets or services. Code is MIT; art/greybox is original / self-made CC0. See [`LICENSE`](LICENSE).

## How to run

1. Install Godot 4.7.
2. Open this folder as a project (`project.godot`).
3. Press Play. The title / landing screen loads first.
4. **Play** (or **Continue**) opens the hub. Pick **Forgotten Crypt** or **Howling Cavern**, choose depth 1–3, and enter.
5. **Settings** covers mouse sensitivity, FOV, volume, and graphics quality (Low / Medium / High / Ultra).

Headless tests (same command CI uses):

```bash
godot --headless --path . --import --quit
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . res://tests/smoke_play.tscn
```

Or: `bash scripts/run_tests.sh`

## Controls

| Action | Input |
| --- | --- |
| Move | WASD |
| Look | Mouse |
| Sprint | Shift (uses stamina) |
| Jump | Space |
| Melee | Left mouse |
| Block | Right mouse |
| Ember bolt | F |
| Use / loot / exit | E |
| Inventory | I |
| Bestiary / conquest log | B |
| Pause (save / abandon) | Esc |

Hub: click a dungeon card to select it, click again to enter at the chosen depth. **New game** wipes the save and starter kit.

## What's in the slice

- First-person mover with health, stamina, melee, block, and one ranged spell
- Room-stitched procedural layouts, two data-driven dungeon types, doors, chest rooms, boss + exit
- Five monster definitions (skeleton, cave wolf, wraith, crypt lich, cave troll) with patrol / chase / attack
- Item model with rarity tiers and dungeon-tier scaling, inventory + equip UI
- Bestiary and dungeon-conquered log, JSON save/load (`user://dungeondiver_save.json`)
- Authoritative `GameSession`: local input becomes a `PlayerCommand` in the session inbox; the session applies it on its tick and owns a seeded `RandomNumberGenerator` for loot/combat rolls

## Art

PBR stone / brick / wood / metal / ground maps are CC0 from [Poly Haven](https://polyhaven.com). Creatures, weapons, props, and kit pieces are original Blender meshes (`scripts/blender/generate_assets.py`). Every source is listed in [`assets/CREDITS.md`](assets/CREDITS.md). Visual nodes still use `BodyVisual` / `WeaponVisual` / `ShieldVisual` / `asset_socket` so a later kit can swap in. No paid or store packs.

## Docs

- [`docs/AGENT_CONTEXT.md`](docs/AGENT_CONTEXT.md) — architecture for future agents
- [`docs/roadmap.md`](docs/roadmap.md) — prototype → content → co-op
- [`docs/multiplayer-plan.md`](docs/multiplayer-plan.md) — how co-op should plug in

## Adding content

Drop a `ItemDef` / `MonsterDef` / `DungeonTypeDef` / `LootTable` `.tres` into `data/`. `ContentDB` class-checks and field-validates extras, then merges them on top of the built-in catalog in `src/content/catalog.gd`. Items that are not on any loot table are added to `mixed_drops` so they can drop in play (`ashen_circlet` is the shipped example).

## License

- **Code** — MIT ([`LICENSE`](LICENSE))
- **Assets** — original / self-made, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
