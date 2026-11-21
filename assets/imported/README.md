# Imported 3D assets

Runtime art lives in `res://assets/textures/` and `res://assets/models/`.
Licenses and source URLs: [`ASSET_LICENSES.md`](../ASSET_LICENSES.md).

Greybox nodes are still tagged with `asset_socket` metadata:

- `floor`, `wall`, `ceiling` — dungeon pieces (now PBR-textured primitives)
- `prop_pillar`, `prop_crate`, `prop_barrel`, `prop_rubble`
- `BodyVisual` — monster GLB (player kit is still a first-person greybox)
- `WeaponVisual`, `ShieldVisual` — first-person kit

The hub / level-select scene is unchanged and still uses original greybox
primitives. Dungeon rooms load CC0 PBR textures (Poly Haven) and CC0 GLBs
(KayKit, Quaternius, Kenney).

Original / self-made greybox helpers remain CC0 1.0. Code is MIT. See the
repository `LICENSE`.
