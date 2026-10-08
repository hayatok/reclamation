"""Deterministic original RECLAMATION freight atlas, no external image inputs.

Run with Python and Pillow. Each padded tile is mapped inside a 16 px gutter.
Broad oxidation patches carry the material at RTS scale; no text/logos/decals.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random, json, hashlib

ROOT = Path(__file__).resolve().parents[1]
SIZE, CELL, GUTTER = 1024, 256, 16
PALETTE = [
    ('faded_teal', '#536560', 218, 65),
    ('red_oxide', '#76513b', 232, 32),
    ('exposed_steel', '#858679', 178, 170),
    ('old_timber', '#746046', 240, 0),
    ('cavity_soot', '#343b35', 247, 0),
    ('faded_ochre', '#978254', 227, 40),
    ('old_cream', '#a09b80', 224, 25),
    ('concrete', '#777a6b', 244, 0),
    ('canvas', '#81816a', 248, 0),
    ('dark_steel', '#4b5149', 203, 115),
    ('broad_rust', '#805037', 245, 0),
    ('pale_patch', '#8a9488', 225, 50),
    ('clay', '#755744', 246, 0),
    ('rubber', '#2d3530', 237, 0),
    ('amber_lens', '#be9757', 182, 0),
    ('green_lens', '#8b9b71', 182, 0),
]

def main():
    out = ROOT / 'assets'
    out.mkdir(parents=True, exist_ok=True)
    albedo = Image.new('RGB', (SIZE, SIZE))
    orm = Image.new('RGB', (SIZE, SIZE))
    for i, (name, color, rough, metal) in enumerate(PALETTE):
        rng = random.Random(1040820 + i)
        base = tuple(bytes.fromhex(color[1:]))
        tile = Image.new('RGB', (CELL, CELL), base)
        draw = ImageDraw.Draw(tile)
        # Deliberately large patches: a handful of changes per surface, not grit.
        for n in range(11):
            x, y = rng.randint(-30, 220), rng.randint(-30, 225)
            w, h = rng.randint(30, 100), rng.randint(18, 80)
            shift = rng.choice([-16, -10, 9, 13])
            c = tuple(max(0, min(255, v + shift)) for v in base)
            pts = [(x, y + h*.2), (x+w*.35, y), (x+w, y+h*.16),
                   (x+w*.9, y+h*.7), (x+w*.55, y+h), (x+w*.1, y+h*.85)]
            draw.polygon(pts, fill=c)
        if i in (0, 5, 6, 11):
            for n in range(6):
                x, y = rng.randint(12, 198), rng.randint(12, 202)
                w, h = rng.randint(22, 60), rng.randint(10, 34)
                draw.polygon([(x,y),(x+w*.7,y-4),(x+w,y+h*.4),(x+w*.8,y+h),
                              (x+5,y+h*.8)], fill=(109,76,50))
        if i == 3:
            for k in range(15):
                y = 9 + k * 17
                draw.line((0,y,255,y+rng.randint(-3,3)), fill=(91,75,54), width=2)
            draw.ellipse((138,75,176,87), outline=(81,65,46), width=2)
        if i == 8:
            for k in range(0, 256, 16):
                draw.line((0,k,255,k), fill=(119,120,98), width=1)
        # Crop the painted tile to the safe interior, then extend edge texels.
        inner = tile.crop((GUTTER, GUTTER, CELL-GUTTER, CELL-GUTTER))
        tile.paste(inner, (GUTTER, GUTTER))
        tile.paste(inner.crop((0,0,1,inner.height)).resize((GUTTER,inner.height)), (0,GUTTER))
        tile.paste(inner.crop((inner.width-1,0,inner.width,inner.height)).resize((GUTTER,inner.height)), (CELL-GUTTER,GUTTER))
        tile.paste(tile.crop((0,GUTTER,CELL,GUTTER+1)).resize((CELL,GUTTER)), (0,0))
        tile.paste(tile.crop((0,CELL-GUTTER-1,CELL,CELL-GUTTER)).resize((CELL,GUTTER)), (0,CELL-GUTTER))
        x, y = (i % 4) * CELL, (i // 4) * CELL
        albedo.paste(tile, (x,y))
        orm.paste(Image.new('RGB', (CELL,CELL), (255,rough,metal)), (x,y))
    paths = []
    for kind, im in [('albedo', albedo), ('orm', orm)]:
        path = out / ('freight_yard_' + kind + '.png')
        im.save(path, optimize=True)
        paths.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':path.stat().st_size})
    (ROOT/'reports').mkdir(exist_ok=True)
    (ROOT/'reports/atlas_report.json').write_text(json.dumps({'size':[SIZE,SIZE],'tile_size':CELL,'gutter':GUTTER,'tiles':[p[0] for p in PALETTE],'files':paths},indent=2)+'\n')
    print('Original freight atlas written: 1024px albedo + ORM, 16px tile gutters.')

if __name__ == '__main__':
    main()
