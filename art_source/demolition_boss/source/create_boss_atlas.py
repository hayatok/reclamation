"""Original, deterministic demolition infected surfaces; no external imagery."""
from pathlib import Path
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
COLORS = [
    (139, 148, 132), (104, 113, 100), (169, 166, 143), (85, 74, 69),
    (112, 91, 61), (76, 65, 49), (157, 137, 97), (41, 45, 42),
    (57, 70, 75), (76, 89, 91), (43, 43, 37), (137, 80, 48),
    (166, 160, 144), (121, 119, 108), (74, 58, 43), (191, 182, 151),
]


def main():
    out = ROOT / 'generated'
    out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(23109)
    image = Image.new('RGB', (512, 512))
    for tile, color in enumerate(COLORS):
        tx, ty = (tile % 4) * 128, (tile // 4) * 128
        patch = Image.new('RGB', (128, 128), color)
        pixels = patch.load()
        for y in range(128):
            for x in range(128):
                grain = rng.randint(-8, 8)
                broad = int(5 * (x / 128 - .5) - 8 * (y / 128 - .5))
                if tile in (4, 5, 6, 8, 9):
                    grain += (2 if x % 3 == 0 else 0) - (3 if y % 4 == 0 else 0)
                pixels[x, y] = tuple(max(0, min(255, c + grain + broad)) for c in color)
        d = ImageDraw.Draw(patch)
        if tile in (0, 1, 2, 3):
            for _ in range(16):
                x, y = rng.randrange(12, 115), rng.randrange(12, 115)
                d.ellipse((x, y, x + rng.randrange(3, 14), y + rng.randrange(2, 9)),
                          fill=tuple(max(0, c - rng.randrange(8, 22)) for c in color))
        if tile in (4, 5, 6, 8, 9):
            d.line([(16, 5), (18, 120)], fill=tuple(max(0, c - 20) for c in color), width=2)
            for y in range(6, 121, 9):
                d.line((21, y, 26, y + 2), fill=tuple(min(255, c + 24) for c in color))
            for _ in range(12):
                x, y = rng.randrange(30, 105), rng.randrange(20, 115)
                d.line((x, y, x + rng.randrange(5, 20), y - 2), fill=tuple(min(255, c + 17) for c in color))
        if tile in (12, 13):
            for _ in range(4):
                x, y = rng.randrange(12, 116), rng.randrange(12, 80)
                path = [(x, y)]
                for j in range(4):
                    x += rng.randrange(-10, 11); y += rng.randrange(6, 15)
                    path.append((x, y))
                d.line(path, fill=(88, 85, 77), width=1)
            for _ in range(65):
                x, y = rng.randrange(128), rng.randrange(128)
                d.ellipse((x, y, x + 2, y + 2), fill=(183, 178, 163))
        if tile in (11, 14):
            for _ in range(34):
                x, y = rng.randrange(128), rng.randrange(128)
                d.line((x, y, x + 2, y + rng.randrange(3, 12)), fill=(88, 52, 34), width=2)
        image.paste(patch, (tx, ty))
    image.save(out / 'demolition_boss_atlas.png', optimize=True)
    print(out / 'demolition_boss_atlas.png')


if __name__ == '__main__':
    main()
