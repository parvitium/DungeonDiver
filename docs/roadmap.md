# Roadmap

## Phase 1 — Prototype (this slice)

Playable solo loop that proves the fantasy:

- [x] First-person move / look / sprint / jump
- [x] Melee, block, one spell; health + stamina
- [x] Two data-driven dungeon types, stitched rooms, doors, boss exit
- [x] Three regular monsters + bosses, patrol/chase/attack, navmesh
- [x] Loot rarities, inventory/equip, gear scales with tier/depth
- [x] Bestiary + conquest log, save/load
- [x] Authoritative session + command-shaped input
- [x] Headless tests + GitHub Actions import/test
- [x] Title / landing screen with cinematic hall and settings
- [x] PBR dungeon kit, torches, props, AgX grading
- [x] Authored monster meshes + first-person sword/shield
- [ ] Feel pass (attack juice, hit react, audio)
- [ ] Death/loot rules tuned with playtests

## Phase 2 — Content

Make the collection goal real without rewriting systems.

- More dungeon types as `.tres` (each with palette, pool, boss, loot table)
- More monsters and a boss per dungeon, still data-driven AI parameters
- Replace greybox sockets with Blender `.glb` kits (floors, walls, creatures, weapons)
- Affixes on items, set bonuses, stash at the hub
- Classes / races (the original README pitch) as profile flags that tweak `StatBlock`
- Audio: footsteps, hits, dungeon beds (CC0 or original)
- Tutorial / first-run prompting
- Difficulty / depth beyond 3, optional modifiers

## Phase 3 — Co-op

Ship host-authoritative 2–4 player drops-in.

- Implement `docs/multiplayer-plan.md` (ENet / Godot HLM, command stream)
- Shared dungeon seed, host sim, client presentation
- Loot rules for groups (personal rolls vs. need/greed — decide in that phase)
- Revive / downed state, friendly fire off by default
- Hub as a small lobby; matchmaking later if needed (no paid backend in prototype)

Out of scope until Phase 3 is stable: dedicated servers, anti-cheat, cross-play stores.
