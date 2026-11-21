# Asset licenses

Third-party files under `assets/` are free for game use. No paid packs, Meshy,
or Tripo assets are used. Original greybox helpers in code remain CC0 as
stated in the repository `LICENSE`.

| Files | Asset | Author | Source | License |
| --- | --- | --- | --- | --- |
| `textures/castle_brick_01/*` | Castle Brick 01 (1K JPG: diff, nor_gl, rough, ao) | Rob Tuytel / Poly Haven | https://polyhaven.com/a/castle_brick_01 | CC0 1.0 |
| `textures/cobblestone_floor_13/*` | Cobblestone Floor 13 (1K JPG: diff, nor_gl, rough) | Poly Haven | https://polyhaven.com/a/cobblestone_floor_13 | CC0 1.0 |
| `textures/rock_wall_13/*` | Rock Wall 13 (1K JPG: diff, nor_gl, rough, ao) | Poly Haven | https://polyhaven.com/a/rock_wall_13 | CC0 1.0 |
| `textures/rock_face/*` | Rock Face (1K JPG: diff, nor_gl, rough, ao) | Poly Haven | https://polyhaven.com/a/rock_face | CC0 1.0 |
| `textures/weathered_brown_planks/*` | Weathered Brown Planks (1K JPG: diff, nor_gl, rough) | Poly Haven | https://polyhaven.com/a/weathered_brown_planks | CC0 1.0 |
| `models/monsters/pbr_skeleton.glb` | Walking Skeleton (anatomical PBR mesh; idle/walk from source; run/attack/death authored in-repo) | tevy | https://tevy.dev/models/skeleton | CC0 1.0 |
| `models/monsters/pbr_lich.glb` | Walking Skeleton plus in-repo robe, cowl and staff (Poly Haven leather, recolored) | tevy (skeleton); Poly Haven (fabric_leather_01) | https://tevy.dev/models/skeleton · https://polyhaven.com/a/fabric_leather_01 | CC0 1.0 |
| `models/monsters/pbr_wolf.glb` | Animated wolf (female mesh, idle/walk/run/attack/death; coat restyled in-repo) | tomek | https://opengameart.org/content/3d-wolf-animation-for-game | CC0 1.0 |
| `models/monsters/pbr_troll.glb` | Skinny troll (PBR mesh; locomotion authored in-repo from the included armature) | piacenti | https://opengameart.org/content/skinny-troll | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `models/props/Torch_wall.glb`, `Barrel.glb`, `Chest.glb`, `Column.glb`, `Bones.glb`, `Candle.glb`, `Rock1-3.glb` | Modular Dungeon Pack | Quaternius | https://quaternius.com/packs/medievaldungeon.html | CC0 1.0 |
| `models/props/Crate.glb` | Crate | Quaternius | [Ultimate Fantasy RTS](https://quaternius.com/packs/ultimatefantasyrts.html) | CC0 1.0 |

Wraith reuses `pbr_skeleton.glb` with a translucent emissive PBR material at
runtime. Crypt Lich is the same skeleton under a dark robe and staff. Attack,
death and run clips on the skeleton/lich, and the robe/cowl/staff meshes, are
original work in this repository.

## Attribution (CC-BY)

Cave Troll visual: **piacenti** — [Skinny troll](https://opengameart.org/content/skinny-troll), CC-BY 3.0.

Poly Haven license: https://polyhaven.com/license (CC0).
CC0 deed: https://creativecommons.org/publicdomain/zero/1.0/.
CC-BY 3.0: https://creativecommons.org/licenses/by/3.0/.

Quaternius packs listed above are the older CC0 releases, not later QAL packs.

## Mixamo

Adobe Mixamo characters and animations are free for game use with an Adobe ID
(royalty-free in video games; do not redistribute the raw files as a standalone
asset pack). This project does not bundle Mixamo files: mixamo.com required a
login we could not complete from this environment.

## Sources checked but not used

Sketchfab CC-BY downloads (API 401 / `mayDownloadThisModel` false without a
token), including Hiago Tadeu's realistic grey wolf
(https://sketchfab.com/3d-models/wolf-9e7aceacef0f4486b605abdf1f62e4ac, CC-BY 4.0)
and AiZity's rehost of it (HTTP 429 challenge); Mixamo.com characters (account
required); Quaternius Ultimate Monsters (cartoon zombie/ghost/orc — the previous
QA fail); KayKit Skeletons (chibi); Kenney Mini Dungeon orc (voxel); OpenGameArt
werewolf (bipedal); OpenGameArt Troll Mauler (unrigged 4K blend); OpenGameArt
Dungeon Pack 1 ogre (CC-BY-SA, no armature); OpenGameArt Skeleton Outlaw (Mixamo
boots/armor, not a bare skeleton); OpenGameArt NewDLC "3d wolf" (cartoon dog
face); OpenGameArt CoinCoin animated wolf (stylized teal); OpenGameArt Undead
Mage (USD/posed only, no game clips); Grab3D / Dire Wolf Lite (Meshy-generated,
excluded); 3DAssets.dev grey wolf (smooth unrigged cartoon).
