# Co-op plan (not implemented)

DungeonDiver should stay **host-authoritative**. The prototype already splits “what the player wants” from “what the world does” so this phase can add networking without rewriting combat.

## Goals

- 2–4 players in one generated dungeon
- One host (listen-server) owns `GameSession`, RNG, hits, loot, and clears
- Clients send intent only; they do not spawn loot or record bestiary locally
- Same content defs on every peer (catalog + `data/*.tres` must match)

## What already exists for this

| Piece | Role later |
| --- | --- |
| `PlayerCommand` | Serialized input tick (move, look, buttons) |
| `Player.apply_command` | Host-run pawn step |
| `GameRNG` + run seed | Host picks seed; all generation is deterministic from it |
| `GameSession` | Becomes the host singleton; clients get snapshots / RPCs |
| Entity ids on items/monsters | Replicated spawn keys |
| `CombatResolver` / `LootGenerator` | Run only on host |

Do **not** put `multiplayer.is_server()` checks inside `CombatResolver` or `Catalog`. Keep those pure.

## Recommended Godot stack

- High-level multiplayer (`ENetMultiplayerPeer` first; Steam/EOS later if wanted)
- `MultiplayerSpawner` for player pawns and monsters *after* the host builds the dungeon
- Reliable RPCs for interact, equip, chest, exit
- Unreliable or unreliable-ordered for look/move if bandwidth matters; 20–30 Hz is enough for this slice

Avoid replicating every `CharacterBody3D` property. Replicate:

1. Commands (client → host)
2. Transform + vitals + state enum (host → clients)
3. Discrete events: spawn, die, loot drop, door unlock, run end

## Session flow

1. Host opens a listen server from the hub. Clients join with a name.
2. Host keeps one `PlayerProfile` per peer (inventory is per-player).
3. Party selects dungeon + depth. Host calls `start_run` once, replicates the seed and dungeon id. Everyone builds the same `DungeonBlueprint` locally **or** host builds and spawns; prefer **shared seed + local build** for greybox geometry to cut spawn traffic.
4. Host spawns monsters with ids. Clients instance ghosts keyed by those ids.
5. On kill, host updates that peer’s bestiary and rolls loot. Drops are world entities with ids; any player can interact; host grants the item to that profile.
6. Exit: host requires boss dead, then `end_run(true)` for all, writing each profile’s conquest if they were present.

## Authority rules

- Hits: only host calls `receive_hit` for real damage. Clients may play swings immediately (prediction) but health is host-corrected.
- Stamina/health: host sim; clients interpolate bars.
- Inventory/equip: request RPC → host mutates `Inventory` → replicate bag snapshot.
- Save: each client saves its own profile; host does not write other people’s disks.

## What not to do in Phase 1

- No `rpc()` on player or monster yet (avoids half-wired net)
- No lobby backend, relay, or paid service
- No client-side loot generation

## First implementation slice (when we start Phase 3)

1. Listen server + join from hub, spawn extra `Player` pawns
2. Route remote peers through `PlayerCommand.from_dict`
3. Replicate monster health/deaths
4. Shared exit / wipe handling
5. Only then: drop-in, voice-adjacent UI, more than two players

## Risks

- Navmesh + avoidance with multiple agents (budget test at 4 players + 12 mobs)
- Desync if a peer has different `data/*.tres` — show a content hash in the lobby
- Steal-a-kill loot drama — pick a rule before coding drops
