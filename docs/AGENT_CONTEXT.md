# Agent context — DungeonDiver

Read this before changing gameplay, content, or net-facing code.

## What this game is

A first-person dungeon crawler. The long-term player goal is **collection**: defeat every monster type and conquer every dungeon type, while gear gets better with dungeon tier and depth. Co-op is planned; networking is not implemented yet.

Engine: **Godot 4.7**, GDScript only. Owner also ships UltimateTowerDefense in Godot and authors 3D in Blender, so keep greybox sockets and `.glb` swap paths intact.

## Layout

```
src/core/           Pure simulation (stats, combat math, commands, RNG). No nodes.
src/content/        Resource defs + built-in Catalog.
src/loot/           ItemInstance, LootGenerator, Inventory.
src/dungeon/        Blueprint + generator (data only).
src/progression/    Bestiary + conquest + PlayerProfile.
src/autoload/       ContentDB, GameSession (authority), SaveService.
src/player/         CharacterBody3D pawn that *applies* PlayerCommand.
src/monster/        Navmesh AI pawn.
src/world/          Builders, hub, run controller, projectiles, interactables.
src/ui/             HUD / inventory / bestiary / pause (built in code).
data/               Optional extra .tres packs.
tests/              Headless runner, no GUT vendor.
```

Autoload order: `ContentDB` → `GameSession` → `SaveService`.

## Invariants

1. **GameSession is the authority.** Profile, run seed, loot grants, kills, clears, the command inbox, and the seeded RNG go through it. Do not write progression from UI widgets except via inventory helpers + `profile_changed`.
2. **Input is a command.** `Player.gather_command()` reads Godot input and **submits** it with `GameSession.submit_command`. `GameSession.tick` applies the inbox via `Player.apply_command`. Do not call `apply_command` from `_physics_process`, and do not sprinkle `Input.is_action_*` inside combat math. Set `GameSession.accept_local_input = false` when injecting host/remote commands.
3. **Content is data.** New dungeon/monster/item = Resource + catalog or `data/*.tres`. Do not hard-code type lists in UI; iterate `ContentDB`.
4. **Scaling is centralized.** `DD.effective_tier`, `DD.depth_scale`, `DD.rarity_weights_for_tier`, `LootGenerator`, `CombatResolver.scaled_monster_*`. If a number changes with depth, it belongs there so tests can lock it.
5. **Greybox is disposable.** Visual nodes are named `BodyVisual` / `WeaponVisual` / `ShieldVisual` or tagged `asset_socket`. Simulation must not depend on mesh shape beyond collision the builder already creates.
6. **No paid assets or services.** Placeholders only; credit any future CC0.

## How a run works

1. Hub calls `GameSession.start_run(id, depth)`.
2. `DungeonGenerator` grows a connected room graph from `(0,0)`, farthest cell is the boss+exit.
3. `DungeonBuilder` instances primitives, bakes `NavigationRegion3D`.
4. `dungeon_run.gd` spawns player, monsters, chests, locked exit.
5. Boss death unlocks the exit. Exit or death/abandon calls `GameSession.end_run`.
6. Victory records `progression.record_clear`. Any kill records bestiary.

Save file: `user://dungeondiver_save.json`, versioned by `DD.SAVE_VERSION`. Load type-checks every nested field, drops unknown catalog ids, rejects newer versions, and never assigns a half-decoded profile. Corrupt files are copied to `<save>.corrupt-<unix>` and the session starts fresh.

## Tests

`godot --headless --path . -s res://tests/run_tests.gd`

Math and generation must stay green. If you change loot curves or dungeon connectivity, update tests in the same change.

## Multiplayer later

See `docs/multiplayer-plan.md`. Do not add RPCs until that plan is being executed. Keep new gameplay state on `GameSession` or components that do not read `Input` directly.

## Godot notes

- Physics layers: world 1, player 2, monster 3, projectile 4, interactable 5, hurtbox 6 (`DD.HURTBOX_LAYER`, unused in this slice).
- Project feature set: 4.7 Forward Plus.
- First import writes `.godot/` (gitignored). CI imports fresh.
