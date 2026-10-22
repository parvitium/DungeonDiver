# Imported Blender assets

Drop exported `.glb` files here. Greybox nodes are tagged with `asset_socket` metadata:

- `floor`, `wall`, `ceiling` — dungeon pieces
- `BodyVisual` — player/monster mesh
- `WeaponVisual`, `ShieldVisual` — first-person kit

To swap a placeholder, instance the glb as a child of the matching node (or replace the MeshInstance3D) without changing simulation scripts.

Greybox art in this repo is original / self-made and released under CC0 1.0. Code is MIT. See the repository `LICENSE`.
