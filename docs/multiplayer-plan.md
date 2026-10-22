# Co-op plan

DungeonDiver is **host-authoritative** when co-op is added. Networking is **not** implemented. This document describes what the prototype actually does today, then how Phase 3 should use that split.

## What exists now (prototype)

These pieces are wired and tested. Do not describe them as more than this.

| Piece | What it does today |
| --- | --- |
| `PlayerCommand` | One tick of intent (move, look, jump, sprint, melee, block, cast, interact). `to_dict` / `from_dict` for later RPCs. |
| `Player.gather_command()` | Reads Godot `Input` + mouse look on the local pawn. |
| `GameSession` command inbox | `Player._physics_process` calls `GameSession.submit_command(gather_command())` when `accept_local_input` is true. It does **not** apply the command itself. |
| `GameSession.tick(delta)` | Runs on the session's `_physics_process` with `process_physics_priority` 20 (after pawns at 0). Pawns submit this frame, then the session drains the inbox and calls `Player.apply_command(cmd, delta)` on the first `"player"` node — same frame, no inbox lag. Tests call `tick` directly. |
| `Player.apply_command` | The only pawn step. Host (and today's solo session) run this. |
| `GameSession.rng` | A `GameRNG` wrapping a seeded `RandomNumberGenerator`. `start_run` reseeds it from `run.seed_value`. Loot (`roll_table`), monster drop chance, and combat rolls use this stream. `CombatResolver` stays pure math. |
| `GameSession.ai_rng` | A second `GameRNG`, seeded from the same run seed with a fixed salt. Monster patrol, AI, and mob entity ids use this stream so they cannot desync loot. |
| Determinism | Same `seed_value` + same `PlayerCommand` sequence produces the same loot and AI. Patrol ticks do not consume the loot stream (`tests/test_command.gd`). |
| `ContentDB` | Shared defs. Extra `.tres` files are class-checked (`is ItemDef` / `MonsterDef` / `DungeonTypeDef` / `LootTable`) and field-validated before insert. |
| Entity ids on items/monsters | Spawn keys (`GameRNG.next_id`). |
| `CombatResolver` / `LootGenerator` | Pure functions. Session supplies the RNG. No `multiplayer.is_server()` inside them. |

Solo play already goes through the inbox. There is no ENet peer, no RPC, no listen server, no snapshot replication.

Set `GameSession.accept_local_input = false` when a future host is applying remote commands so the pawn does not also submit local `Input`.

## Goals (not built)

- 2–4 players in one generated dungeon
- One host (listen-server) owns `GameSession`, RNG, hits, loot, and clears
- Clients send `PlayerCommand` only; they do not spawn loot or record bestiary locally
- Same content defs on every peer (catalog + `data/*.tres` must match)

## Recommended Godot stack (Phase 3)

- High-level multiplayer (`ENetMultiplayerPeer` first; Steam/EOS later if wanted)
- `MultiplayerSpawner` for player pawns and monsters *after* the host builds the dungeon
- Reliable RPCs for interact, equip, chest, exit
- Unreliable or unreliable-ordered for look/move if bandwidth matters; 20–30 Hz is enough for this slice

Avoid replicating every `CharacterBody3D` property. Replicate:

1. Commands (client → host inbox)
2. Transform + vitals + state enum (host → clients)
3. Discrete events: spawn, die, loot drop, door unlock, run end

## Session flow (Phase 3)

1. Host opens a listen server from the hub. Clients join with a name.
2. Host keeps one `PlayerProfile` per peer (inventory is per-player).
3. Party selects dungeon + depth. Host calls `start_run` once, replicates the seed and dungeon id. Everyone builds the same `DungeonBlueprint` locally **or** host builds and spawns; prefer **shared seed + local build** for greybox geometry to cut spawn traffic.
4. Host spawns monsters with ids. Clients instance ghosts keyed by those ids.
5. On kill, host updates that peer’s bestiary and rolls loot from `GameSession.rng`. Drops are world entities with ids; any player can interact; host grants the item to that profile.
6. Exit: host requires boss dead, then `end_run(true)` for all, writing each profile’s conquest if they were present.

## Authority rules (Phase 3)

- Hits: only host calls `receive_hit` for real damage. Clients may play swings immediately (prediction) but health is host-corrected.
- Stamina/health: host sim; clients interpolate bars.
- Inventory/equip: request RPC → host mutates `Inventory` → replicate bag snapshot.
- Save: each client saves its own profile; host does not write other people’s disks.

## What not to do until Phase 3 starts

- No `rpc()` on player or monster (avoids half-wired net)
- No lobby backend, relay, or paid service
- No client-side loot generation
- Do not put `multiplayer.is_server()` inside `CombatResolver` or `Catalog`

## First implementation slice (when we start Phase 3)

1. Listen server + join from hub, spawn extra `Player` pawns
2. Route remote peers through `PlayerCommand.from_dict` → `GameSession.submit_command`
3. Replicate monster health/deaths
4. Shared exit / wipe handling
5. Only then: drop-in, voice-adjacent UI, more than two players

## Risks

- Navmesh + avoidance with multiple agents (budget test at 4 players + 12 mobs)
- Desync if a peer has different `data/*.tres` — show a content hash in the lobby
- Steal-a-kill loot drama — pick a rule before coding drops
