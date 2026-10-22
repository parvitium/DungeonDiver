# DungeonDiver

First-person fantasy dungeon explorer. Fight monsters, take their gear, and keep going until every dungeon type and every monster type is in the book.

This repository is a **playable vertical-slice prototype** in **Godot 4.7**. Rooms are greybox primitives so Blender `.glb` meshes can replace them later. Co-op is designed for, not shipped — see [`docs/multiplayer-plan.md`](docs/multiplayer-plan.md).

## Requirements

- [Godot 4.7.x](https://godotengine.org/download/linux/) (4.7.2 used in CI)
- No paid assets or services. All art in this slice is self-made greybox (public domain / CC0 as part of the repo).

## How to run

1. Install Godot 4.7.
2. Open this folder as a project (`project.godot`).
3. Press Play. The hub loads first.
4. Pick **Forgotten Crypt** or **Howling Cavern**, choose depth 1–3, and enter.

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
- Authoritative session + `PlayerCommand` so input stays separable from simulation

## Placeholder vs real content

Everything you see is a primitive: boxes, capsules, and colored lights. Sockets for future Blender exports are documented in [`assets/imported/README.md`](assets/imported/README.md). No Kenney / store packs are vendored.

## Docs

- [`docs/AGENT_CONTEXT.md`](docs/AGENT_CONTEXT.md) — architecture for future agents
- [`docs/roadmap.md`](docs/roadmap.md) — prototype → content → co-op
- [`docs/multiplayer-plan.md`](docs/multiplayer-plan.md) — how co-op should plug in

## Adding content

Drop a `ItemDef` / `MonsterDef` / `DungeonTypeDef` / `LootTable` `.tres` into `data/`. `ContentDB` merges those on top of the built-in catalog in `src/content/catalog.gd`.
