#!/usr/bin/env python3
"""Download 1K CC0 PBR maps from Poly Haven (and ambientCG fallback)."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "textures"

# dest_folder -> polyhaven asset id
POLYHAVEN = {
    "crypt_brick": "stone_brick_wall_001",
    "crypt_floor": "cobblestone_floor_04",
    "cavern_rock": "rock_wall_10",
    "cavern_floor": "forest_ground_04",
    "wood": "weathered_planks",
    "metal": "rusty_metal_02",
    "bone": "coast_sand_02",
}

# fallbacks if a Poly Haven id 404s
POLYHAVEN_FALLBACK = {
    "crypt_brick": ["brick_wall_02", "castle_brick_07", "plastered_stone_wall"],
    "crypt_floor": ["cobblestone_floor_13", "cobblestone_01", "paving_stones_22"],
    "cavern_rock": ["rock_wall_08", "rock_face", "rock_06"],
    "cavern_floor": ["forest_ground_03", "aerial_rocks_02", "dirt_floor"],
    "wood": ["wood_planks_grey", "ancient_wooden_planks", "wood_table_001"],
    "metal": ["rusty_metal", "metal_plate", "corrugated_iron_02"],
    "bone": ["concrete_layers_02", "limestone_01", "plaster_02"],
}

MAPS = {
    "Diffuse": "albedo.jpg",
    "nor_gl": "normal.jpg",
    "Rough": "roughness.jpg",
    "AO": "ao.jpg",
}

USER_AGENT = "DungeonDiver-asset-fetch/1.0 (CC0 credit in-repo)"


def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    force = os.environ.get("DD_FORCE_TEXTURES") == "1"
    if dest.exists() and dest.stat().st_size > 1024 and not force:
        print(f"  skip {dest.relative_to(ROOT)}")
        return
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as resp:
        dest.write_bytes(resp.read())
    print(f"  got  {dest.relative_to(ROOT)}  ({dest.stat().st_size} bytes)")


def resolve_asset(preferred: str, fallbacks: list[str]) -> str | None:
    for asset_id in [preferred, *fallbacks]:
        try:
            data = fetch_json(f"https://api.polyhaven.com/files/{asset_id}")
        except urllib.error.HTTPError as exc:
            print(f"  miss {asset_id}: {exc.code}")
            continue
        if "Diffuse" in data:
            return asset_id
        print(f"  miss {asset_id}: no Diffuse")
    return None


def pull_polyhaven() -> dict[str, str]:
    credits: dict[str, str] = {}
    for folder, preferred in POLYHAVEN.items():
        fallbacks = POLYHAVEN_FALLBACK.get(folder, [])
        print(f"== {folder}")
        asset_id = resolve_asset(preferred, fallbacks)
        if not asset_id:
            print(f"  FAIL {folder}")
            continue
        files = fetch_json(f"https://api.polyhaven.com/files/{asset_id}")
        credits[folder] = asset_id
        for map_key, filename in MAPS.items():
            dest = OUT / folder / filename
            block = files.get(map_key, {})
            jpg = block.get("1k", {}).get("jpg")
            if not jpg:
                print(f"  no {map_key} for {asset_id}")
                continue
            download(jpg["url"], dest)
    return credits


def pull_ambientcg_zip(asset_id: str, dest_folder: str) -> None:
    """Optional extra pack if a Poly Haven set is incomplete."""
    url = f"https://ambientCG.com/get?file={asset_id}_1K-JPG.zip"
    zip_path = Path("/tmp/downloads") / f"{asset_id}_1K-JPG.zip"
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        download(url, zip_path)
    except Exception as exc:
        print(f"  ambientCG {asset_id} failed: {exc}")
        return
    import zipfile

    dest = OUT / dest_folder
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            name = info.filename.lower()
            if name.endswith("/"):
                continue
            target = None
            if "color" in name or "diff" in name:
                target = dest / "albedo.jpg"
            elif "normalgl" in name or "normal_gl" in name or "nor_gl" in name:
                target = dest / "normal.jpg"
            elif "rough" in name:
                target = dest / "roughness.jpg"
            elif "ambientocclusion" in name or name.endswith("_ao.jpg"):
                target = dest / "ao.jpg"
            if target and (not target.exists() or target.stat().st_size < 1024):
                target.write_bytes(zf.read(info))
                print(f"  unzip {target.relative_to(ROOT)}")


def main() -> int:
    credits = pull_polyhaven()
    for folder, files in ((p.name, list(p.glob("*.jpg"))) for p in OUT.iterdir() if p.is_dir()):
        names = {f.name for f in files}
        if "albedo.jpg" not in names:
            print(f"incomplete {folder}: {sorted(names)}")
    print("resolved", credits)
    (OUT / "sources.json").write_text(json.dumps(credits, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
