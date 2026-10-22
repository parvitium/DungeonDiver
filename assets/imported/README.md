# Imported Blender assets

Authored meshes already ship under `assets/meshes/` (kit, props, weapons, monsters). Drop replacement `.glb` files here or over those paths. Visual nodes are tagged with `asset_socket` metadata:

- `floor`, `wall`, `ceiling` — dungeon pieces
- `BodyVisual` — player/monster mesh
- `WeaponVisual`, `ShieldVisual` — first-person kit
- `torch`, `barrel`, `chest`, `bones`, `chain` — props

To swap a mesh, instance the glb as a child of the matching node (or replace the MeshInstance3D) without changing simulation scripts.

Regenerate the shipped kit with:

`blender --background --python scripts/blender/generate_assets.py`

Regenerate creatures with:

`blender --background --python scripts/blender/generate_creatures.py`

Art is CC0 (original meshes, Quaternius wolf, Poly Haven textures). See `assets/CREDITS.md`. Code is MIT.
