#!/usr/bin/env python3
"""Generate original 1K CC0 creature PBR maps and recompress shipped JPGs."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / "assets" / "textures"
SIZE = 1024
JPEG_Q = 72


def _hash_noise(x: int, y: int, seed: int) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 1274126177) & 0x7FFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    return (n & 0x7FFFFFFF) / 2147483647.0


def value_noise(w: int, h: int, scale: float, seed: int) -> list[list[float]]:
    grid: list[list[float]] = []
    for y in range(h):
        row: list[float] = []
        for x in range(w):
            fx = x / scale
            fy = y / scale
            x0 = int(math.floor(fx))
            y0 = int(math.floor(fy))
            tx = fx - x0
            ty = fy - y0
            tx = tx * tx * (3.0 - 2.0 * tx)
            ty = ty * ty * (3.0 - 2.0 * ty)
            n00 = _hash_noise(x0, y0, seed)
            n10 = _hash_noise(x0 + 1, y0, seed)
            n01 = _hash_noise(x0, y0 + 1, seed)
            n11 = _hash_noise(x0 + 1, y0 + 1, seed)
            row.append(n00 * (1 - tx) * (1 - ty) + n10 * tx * (1 - ty) + n01 * (1 - tx) * ty + n11 * tx * ty)
        grid.append(row)
    return grid


def fbm(w: int, h: int, scales: list[tuple[float, float]], seed: int) -> list[list[float]]:
    acc = [[0.0] * w for _ in range(h)]
    total = 0.0
    for i, (scale, amp) in enumerate(scales):
        n = value_noise(w, h, scale, seed + i * 17)
        total += amp
        for y in range(h):
            for x in range(w):
                acc[y][x] += n[y][x] * amp
    if total <= 0:
        return acc
    for y in range(h):
        for x in range(w):
            acc[y][x] /= total
    return acc


def to_img(grid: list[list[float]], tint: tuple[int, int, int] | None = None) -> Image.Image:
    h = len(grid)
    w = len(grid[0])
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            v = max(0.0, min(1.0, grid[y][x]))
            if tint:
                px[x, y] = (int(tint[0] * v), int(tint[1] * v), int(tint[2] * v))
            else:
                g = int(v * 255)
                px[x, y] = (g, g, g)
    return im


def height_to_normal(height: list[list[float]], strength: float = 2.4) -> Image.Image:
    h = len(height)
    w = len(height[0])
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            dx = height[y][(x + 1) % w] - height[y][(x - 1) % w]
            dy = height[(y + 1) % h][x] - height[(y - 1) % h][x]
            nx = -dx * strength
            ny = -dy * strength
            nz = 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
            px[x, y] = (
                int((nx / length * 0.5 + 0.5) * 255),
                int((ny / length * 0.5 + 0.5) * 255),
                int((nz / length * 0.5 + 0.5) * 255),
            )
    return im


def save_set(folder: str, albedo: Image.Image, normal: Image.Image, rough: Image.Image, ao: Image.Image) -> None:
    dest = TEX / folder
    dest.mkdir(parents=True, exist_ok=True)
    albedo.save(dest / "albedo.jpg", "JPEG", quality=JPEG_Q, optimize=True)
    normal.save(dest / "normal.jpg", "JPEG", quality=JPEG_Q, optimize=True)
    rough.save(dest / "roughness.jpg", "JPEG", quality=JPEG_Q, optimize=True)
    ao.save(dest / "ao.jpg", "JPEG", quality=JPEG_Q, optimize=True)
    print(f"wrote {folder}")


def make_skin() -> None:
    n = SIZE
    mottled = fbm(n, n, [(48, 0.55), (18, 0.30), (7, 0.15)], 11)
    pores = fbm(n, n, [(4.5, 0.7), (2.2, 0.3)], 29)
    albedo = Image.new("RGB", (n, n))
    height = [[0.0] * n for _ in range(n)]
    rough = [[0.0] * n for _ in range(n)]
    px = albedo.load()
    rng = random.Random(2026)
    scars = []
    for _ in range(7):
        scars.append(
            (
                rng.randint(80, n - 80),
                rng.randint(80, n - 80),
                rng.uniform(-0.8, 0.8),
                rng.randint(90, 220),
            )
        )
    warts = [(rng.randint(40, n - 40), rng.randint(40, n - 40), rng.uniform(6, 16)) for _ in range(28)]
    for y in range(n):
        for x in range(n):
            m = mottled[y][x]
            p = pores[y][x]
            r = 132 + m * 58 + p * 12
            g = 148 + m * 48 - p * 6
            b = 92 + m * 32
            hx = 0.42 + m * 0.18 + p * 0.08
            rg = 0.58 + (1.0 - m) * 0.22
            for sx, sy, ang, length in scars:
                dx = x - sx
                dy = y - sy
                ca, sa = math.cos(ang), math.sin(ang)
                along = dx * ca + dy * sa
                across = -dx * sa + dy * ca
                if 0 <= along <= length and abs(across) < 2.6:
                    r = r * 0.62 + 70
                    g = g * 0.55 + 40
                    b = b * 0.5 + 32
                    hx -= 0.12
                    rg = 0.38
            for wx, wy, rad in warts:
                d = math.hypot(x - wx, y - wy)
                if d < rad:
                    t = 1.0 - d / rad
                    bump = math.sin(t * math.pi) ** 1.4
                    r = r * (1.0 - 0.25 * bump) + 70 * bump
                    g = g * (1.0 - 0.18 * bump) + 90 * bump
                    b = b * (1.0 - 0.2 * bump) + 50 * bump
                    hx += 0.38 * bump
                    rg += 0.18 * bump
            px[x, y] = (int(max(0, min(255, r))), int(max(0, min(255, g))), int(max(0, min(255, b))))
            height[y][x] = max(0.0, min(1.0, hx))
            rough[y][x] = max(0.0, min(1.0, rg))
    ao = [[0.55 + mottled[y][x] * 0.4 - pores[y][x] * 0.1 for x in range(n)] for y in range(n)]
    save_set("skin", albedo, height_to_normal(height, 3.1), to_img(rough), to_img(ao))


def make_fur() -> None:
    n = SIZE
    base = fbm(n, n, [(64, 0.45), (22, 0.35), (8, 0.20)], 4)
    albedo = Image.new("RGB", (n, n))
    height = [[0.0] * n for _ in range(n)]
    rough = [[0.0] * n for _ in range(n)]
    px = albedo.load()
    rng = random.Random(77)
    streaks = []
    for _ in range(420):
        streaks.append(
            (
                rng.randint(0, n - 1),
                rng.randint(0, n - 1),
                rng.uniform(-0.35, 0.35),
                rng.randint(18, 70),
                rng.choice(
                    [
                        (36, 26, 18),
                        (118, 78, 42),
                        (168, 132, 88),
                        (28, 24, 22),
                        (86, 64, 44),
                        (150, 118, 78),
                    ]
                ),
            )
        )
    for y in range(n):
        for x in range(n):
            m = base[y][x]
            r = 42 + m * 78
            g = 30 + m * 48
            b = 20 + m * 28
            px[x, y] = (int(r), int(g), int(b))
            height[y][x] = 0.35 + m * 0.2
            rough[y][x] = 0.78 + m * 0.16
    draw = ImageDraw.Draw(albedo)
    for sx, sy, ang, length, color in streaks:
        ca, sa = math.cos(ang), math.sin(ang)
        x1 = sx + ca * length
        y1 = sy + sa * length
        draw.line((sx, sy, x1, y1), fill=color, width=1)
        for i in range(length):
            xx = int(sx + ca * i) % n
            yy = int(sy + sa * i) % n
            height[yy][xx] = min(1.0, height[yy][xx] + 0.18)
            rough[yy][xx] = min(1.0, rough[yy][xx] + 0.04)
    albedo = albedo.filter(ImageFilter.GaussianBlur(radius=0.6))
    albedo = ImageEnhance.Color(albedo).enhance(1.08)
    ao = [[0.5 + base[y][x] * 0.45 for x in range(n)] for y in range(n)]
    save_set("fur", albedo, height_to_normal(height, 2.6), to_img(rough), to_img(ao))


def recompress_existing() -> None:
    for path in TEX.rglob("*.jpg"):
        if path.name == "sources.json":
            continue
        im = Image.open(path)
        im = im.convert("RGB")
        if max(im.size) > SIZE:
            im.thumbnail((SIZE, SIZE), Image.Resampling.LANCZOS)
        tmp = path.with_suffix(".jpg.tmp")
        im.save(tmp, "JPEG", quality=JPEG_Q, optimize=True)
        if tmp.stat().st_size < path.stat().st_size or max(Image.open(path).size) > SIZE:
            tmp.replace(path)
            print(f"compressed {path.relative_to(ROOT)} -> {path.stat().st_size}")
        else:
            tmp.unlink(missing_ok=True)


def patch_imports() -> None:
    for path in TEX.rglob("*.jpg.import"):
        text = path.read_text()
        lines = []
        is_normal = path.name.startswith("normal.")
        for line in text.splitlines():
            if line.startswith("compress/mode="):
                line = "compress/mode=2"
            elif line.startswith("mipmaps/generate="):
                line = "mipmaps/generate=true"
            elif line.startswith("process/size_limit="):
                line = "process/size_limit=1024"
            elif line.startswith("detect_3d/compress_to="):
                line = "detect_3d/compress_to=1"
            elif line.startswith("compress/normal_map="):
                line = "compress/normal_map=1" if is_normal else "compress/normal_map=0"
            elif line.startswith("compress/lossy_quality="):
                line = "compress/lossy_quality=0.72"
            lines.append(line)
        path.write_text("\n".join(lines) + "\n")


def write_import_stub(folder: str) -> None:
    dest = TEX / folder
    for name, normal in (("albedo.jpg", False), ("normal.jpg", True), ("roughness.jpg", False), ("ao.jpg", False)):
        path = dest / f"{name}.import"
        if path.exists():
            continue
        path.write_text(
            "\n".join(
                [
                    "[remap]",
                    "",
                    'importer="texture"',
                    'type="CompressedTexture2D"',
                    "",
                    "[deps]",
                    "",
                    f'source_file="res://assets/textures/{folder}/{name}"',
                    "",
                    "[params]",
                    "",
                    "compress/mode=2",
                    "compress/high_quality=false",
                    "compress/lossy_quality=0.72",
                    "compress/uastc_level=0",
                    "compress/rdo_quality_loss=0.0",
                    "compress/hdr_compression=1",
                    f"compress/normal_map={'1' if normal else '0'}",
                    "compress/channel_pack=0",
                    "mipmaps/generate=true",
                    "mipmaps/limit=-1",
                    "roughness/mode=0",
                    'roughness/src_normal=""',
                    "process/fix_alpha_border=true",
                    "process/premult_alpha=false",
                    "process/normal_map_invert_y=false",
                    "process/hdr_as_srgb=false",
                    "process/hdr_clamp_exposure=false",
                    "process/size_limit=1024",
                    "detect_3d/compress_to=1",
                    "",
                ]
            )
        )


def main() -> int:
    make_skin()
    make_fur()
    write_import_stub("skin")
    write_import_stub("fur")
    recompress_existing()
    patch_imports()
    print("PBR_MAPS_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
