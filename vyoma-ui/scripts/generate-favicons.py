#!/usr/bin/env python3
"""Crop vyomaicon.png to the mark and export crisp favicon / PWA sizes."""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "public"
SRC = PUBLIC / "vyomaicon.png"
BG = (6, 11, 25)  # Vyoma shell background #060B19


def crop_to_mark(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    min_x, min_y = w, h
    max_x, max_y = 0, 0
    found = False

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 48:
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum < 28:
                continue
            found = True
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)

    if not found:
        return rgba

    pad = int(max(max_x - min_x, max_y - min_y) * 0.1)
    min_x = max(0, min_x - pad)
    min_y = max(0, min_y - pad)
    max_x = min(w - 1, max_x + pad)
    max_y = min(h - 1, max_y + pad)
    cropped = rgba.crop((min_x, min_y, max_x + 1, max_y + 1))

    cw, ch = cropped.size
    side = max(cw, ch)
    square = Image.new("RGBA", (side, side), (*BG, 255))
    square.paste(cropped, ((side - cw) // 2, (side - ch) // 2), cropped)
    return square


def export_size(square: Image.Image, size: int, path: Path) -> None:
    resized = square.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGB", (size, size), BG)
    out.paste(resized, mask=resized.split()[3])
    out.save(path, optimize=True)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source: {SRC}")

    mark = crop_to_mark(Image.open(SRC))
    exports = {
        "favicon-16x16.png": 16,
        "favicon-32x32.png": 32,
        "favicon-48x48.png": 48,
        "apple-touch-icon.png": 180,
        "icon-192.png": 192,
        "icon-512.png": 512,
    }
    for name, size in exports.items():
        export_size(mark, size, PUBLIC / name)
        print(f"  {name} ({size}px)")

    # Multi-size ICO for older browsers / Arc bookmarks
    ico_sizes = [16, 32, 48]
    ico_images = [mark.resize((s, s), Image.Resampling.LANCZOS) for s in ico_sizes]
    ico_path = PUBLIC / "favicon.ico"
    ico_images[0].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[1:],
    )
    print(f"  favicon.ico")


if __name__ == "__main__":
    main()
