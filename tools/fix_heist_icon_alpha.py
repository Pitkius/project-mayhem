#!/usr/bin/env python3
"""Remove flat backgrounds from heist/hacking inventory PNGs and resize to 256px."""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("pip install Pillow", file=sys.stderr)
    sys.exit(1)

IMAGES_DIR = Path(__file__).resolve().parents[1] / "resources" / "[qb]" / "qb-inventory" / "html" / "images"
TARGET = 256

NAMES = (
    "basic_tablet",
    "advanced_tablet",
    "military_tablet",
    "basic_flashdrive",
    "encrypted_flashdrive",
    "military_flashdrive",
    "tow_chain",
    "drill",
    "thermite",
    "security_card_01",
    "security_card_02",
)


def corner_bg_color(img: Image.Image) -> tuple[int, int, int]:
    w, h = img.size
    samples: list[tuple[int, int, int]] = []
    for x, y in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2), (w // 2, 1), (w // 2, h - 2)):
        r, g, b, _ = img.getpixel((x, y))
        samples.append((r, g, b))
    return (
        sum(s[0] for s in samples) // len(samples),
        sum(s[1] for s in samples) // len(samples),
        sum(s[2] for s in samples) // len(samples),
    )


def color_dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def process(path: Path, tolerance: float = 55.0) -> bool:
    img = Image.open(path).convert("RGBA")
    if max(img.size) != TARGET:
        img.thumbnail((TARGET, TARGET), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
        ox = (TARGET - img.width) // 2
        oy = (TARGET - img.height) // 2
        canvas.paste(img, (ox, oy), img)
        img = canvas
    bg = corner_bg_color(img)
    w, h = img.size
    px = img.load()
    changed = False
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            rgb = (r, g, b)
            if color_dist(rgb, bg) <= tolerance:
                px[x, y] = (r, g, b, 0)
                changed = True
                continue
            if r > 160 and g > 160 and b > 160 and max(r, g, b) - min(r, g, b) < 30:
                px[x, y] = (r, g, b, 0)
                changed = True
            elif r > 200 and g > 200 and b > 200:
                px[x, y] = (r, g, b, 0)
                changed = True
    img.save(path, optimize=True)
    return changed


def main() -> int:
    if not IMAGES_DIR.is_dir():
        print(f"Missing: {IMAGES_DIR}", file=sys.stderr)
        return 1
    touched = 0
    for name in NAMES:
        path = IMAGES_DIR / f"{name}.png"
        if not path.is_file():
            print(f"missing {path.name}")
            continue
        if process(path):
            print(f"fixed {path.name}")
            touched += 1
        else:
            print(f"processed {path.name}")
            touched += 1
    print(f"Done. Updated {touched} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
