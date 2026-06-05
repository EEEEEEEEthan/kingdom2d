#!/usr/bin/env python3
"""从 diffuse PNG 烘焙像素法线贴图，颜色量化到 GIMP 调色板。"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageFilter


def load_gpl(path: Path) -> list[tuple[int, int, int, int]]:
    colors: list[tuple[int, int, int, int]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("GIMP") or line.startswith("Channels"):
            continue
        parts = line.split()
        if len(parts) < 4:
            continue
        colors.append(tuple(map(int, parts[:4])))
    if not colors:
        raise ValueError(f"调色板为空: {path}")
    return colors


def pick_flat_colors(palette: list[tuple[int, int, int, int]]) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    opaque = next((c for c in palette if c[:3] == (128, 128, 255) and c[3] == 255), None)
    transparent = next((c for c in palette if c[:3] == (128, 128, 255) and c[3] == 0), None)
    if opaque is None:
        opaque = next(c for c in palette if c[3] == 255)
    if transparent is None:
        transparent = opaque
    return opaque, transparent


def nearest_palette(rgb: tuple[int, int, int], palette: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    best = palette[0]
    best_d = 1 << 30
    for c in palette:
        d = (c[0] - rgb[0]) ** 2 + (c[1] - rgb[1]) ** 2 + (c[2] - rgb[2]) ** 2
        if d < best_d:
            best_d = d
            best = c
    return best


def sample_height(height: Image.Image, x: int, y: int) -> float:
    w, h = height.size
    x = max(0, min(w - 1, x))
    y = max(0, min(h - 1, y))
    return height.getpixel((x, y)) / 255.0


def bake(
    diffuse_path: Path,
    output_path: Path,
    gpl_path: Path,
    blur_radius: float,
    sample_span: int,
    strength: float,
) -> None:
    palette = load_gpl(gpl_path)
    flat_opaque, flat_transparent = pick_flat_colors(palette)

    img = Image.open(diffuse_path).convert("RGBA")
    w, h = img.size
    alpha = img.split()[3]
    height = alpha.filter(ImageFilter.GaussianBlur(blur_radius))
    px = img.load()

    normal = Image.new("RGBA", (w, h), flat_transparent)
    npx = normal.load()

    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            h_l = sample_height(height, x - sample_span, y)
            h_r = sample_height(height, x + sample_span, y)
            h_u = sample_height(height, x, y - sample_span)
            h_d = sample_height(height, x, y + sample_span)
            dx = (h_l - h_r) / (2.0 * sample_span) * strength
            dy = (h_u - h_d) / (2.0 * sample_span) * strength
            nz = 1.0
            length = math.sqrt(dx * dx + dy * dy + nz * nz)
            nx, ny, nz = dx / length, dy / length, nz / length
            rgb = (
                int((nx * 0.5 + 0.5) * 255),
                int((ny * 0.5 + 0.5) * 255),
                int((nz * 0.5 + 0.5) * 255),
            )
            c = nearest_palette(rgb, palette)
            npx[x, y] = c if c[3] else flat_opaque

    output_path.parent.mkdir(parents=True, exist_ok=True)
    normal.save(output_path)
    print(f"baked {w}x{h} -> {output_path} (blur={blur_radius}, span={sample_span}, strength={strength})")


def main() -> None:
    parser = argparse.ArgumentParser(description="烘焙像素法线贴图")
    parser.add_argument("diffuse", type=Path, help="diffuse PNG 路径")
    parser.add_argument("-o", "--output", type=Path, required=True, help="输出法线 PNG 路径")
    parser.add_argument("-p", "--palette", type=Path, default=Path("normal.gpl"), help="GIMP 调色板路径")
    parser.add_argument("-b", "--blur", type=float, default=10.0, help="高度场高斯模糊半径")
    parser.add_argument("-s", "--span", type=int, default=6, help="梯度采样跨度（像素）")
    parser.add_argument("--strength", type=float, default=4.0, help="坡度强度倍率")
    args = parser.parse_args()
    bake(args.diffuse, args.output, args.palette, args.blur, args.span, args.strength)


if __name__ == "__main__":
    main()
