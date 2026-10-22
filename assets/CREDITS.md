# Asset credits

All third-party art in this repository is CC0. Code remains MIT.

## Textures (Poly Haven, CC0 1.0)

Downloaded as 1K JPG (albedo / OpenGL normal / roughness / AO).

| Folder | Asset | URL |
| --- | --- | --- |
| `assets/textures/crypt_brick/` | stone_brick_wall_001 | https://polyhaven.com/a/stone_brick_wall_001 |
| `assets/textures/crypt_floor/` | cobblestone_floor_04 | https://polyhaven.com/a/cobblestone_floor_04 |
| `assets/textures/cavern_rock/` | rock_wall_10 | https://polyhaven.com/a/rock_wall_10 |
| `assets/textures/cavern_floor/` | forest_ground_04 | https://polyhaven.com/a/forest_ground_04 |
| `assets/textures/wood/` | weathered_planks | https://polyhaven.com/a/weathered_planks |
| `assets/textures/metal/` | rusty_metal_02 | https://polyhaven.com/a/rusty_metal_02 |
| `assets/textures/bone/` | plaster_stone_wall_01 | https://polyhaven.com/a/plaster_stone_wall_01 |

Poly Haven license: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). No attribution required; listed here so we can prove provenance.

## Meshes (original, CC0 1.0)

Generated with headless Blender 4.2 via `scripts/blender/generate_assets.py` and `scripts/blender/generate_creatures.py`:

- Modular kit: `assets/meshes/kit/{pillar,arch,beam}.glb`
- Props: `assets/meshes/props/{torch,barrel,chest,chain,bones}.glb`
- Weapons: `assets/meshes/weapons/{sword,shield}.glb`
- Humanoid undead / troll: `assets/meshes/monsters/{skeleton,wraith,lich,cave_troll}.glb` (original Mixamo-style armatures, idle/walk/attack/hit/death)

UV-mapped room slabs, trim, and fallback primitives are built at runtime in `MeshFactory` / `DungeonKit` and are also original CC0.

## Meshes (Quaternius, CC0 1.0)

| File | Source | URL |
| --- | --- | --- |
| `assets/imported/quaternius/Wolf.glb` (processed to `assets/meshes/monsters/cave_wolf.glb`) | Ultimate Animated Animal Pack | https://quaternius.com |

Clips remapped to `idle` / `walk` / `attack` / `hit` / `death`. License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). No attribution required; listed here for provenance.

## Fetch script

`scripts/download_textures.py` records resolved Poly Haven ids in `assets/textures/sources.json`.
