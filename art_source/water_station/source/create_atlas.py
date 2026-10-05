"""Original deterministic municipal-water materials for RECLAMATION.
No downloaded imagery, font files, scans, logos or third-party texture inputs.
Python 3, Pillow and NumPy. All patterns are authored below.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
import random
ROOT=Path(__file__).resolve().parents[1]
for folder in ('assets', 'reports', 'previews', 'source'):
    (ROOT/folder).mkdir(parents=True, exist_ok=True)
N=512
rng=np.random.default_rng(610502)
# concrete, broken concrete, teal enamel, pale enamel, iron, rust,
# brick, mortar, rubber, red valve, dirty water, moss, brass, label, gauge, dark grille
COLORS=[(117,117,101),(148,140,120),(66,102,96),(171,176,148),(49,61,59),(113,77,54),(122,79,61),(128,122,101),(30,37,35),(135,69,50),(47,73,64),(75,86,59),(150,126,77),(182,177,140),(193,190,153),(27,37,35)]
ROUGH=[.96,.96,.86,.87,.77,.95,.99,.99,.95,.86,.63,.99,.78,.94,.90,.92]
METAL=[0,0,.22,.18,.65,.3,0,0,0,.25,0,0,.5,0,0,.3]
albedo=Image.new('RGB',(N*4,N*4)); orm=Image.new('RGB',albedo.size); normal=Image.new('RGB',albedo.size)
for k,base in enumerate(COLORS):
    rr=random.Random(1461+k)
    lo=Image.fromarray(rng.integers(0,256,(13,13),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(5))
    mid=Image.fromarray(rng.integers(0,256,(75,75),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC)
    low=np.array(lo).astype(float)-128
    h=low*.105+(np.array(mid).astype(float)-128)*.045+rng.normal(0,1.5,(N,N))
    arr=np.clip(np.array(base)+h[:,:,None],0,255)
    if k in (2,3,4,5,9):
        rust=np.array((105,72,49)); islands=np.clip((low-34)/52,0,.46)
        arr=arr*(1-islands[:,:,None])+rust*islands[:,:,None]
    tile=Image.fromarray(arr.astype(np.uint8)); d=ImageDraw.Draw(tile,'RGBA')
    for _ in range(210):
        x,y=rr.randrange(N),rr.randrange(N); r=rr.choice([1,1,2,3]); c=rr.randrange(55,170)
        d.ellipse((x-r,y-r,x+r,y+r),fill=(c,c,int(c*.86),rr.randrange(10,40)))
    if k in (0,1,6,7):
        for _ in range(6):
            x,y=rr.randrange(50,N-50),rr.randrange(70,N-150); pts=[(x,y)]
            for j in range(6):x+=rr.randrange(-15,19);y+=rr.randrange(8,22);pts.append((x,y))
            d.line(pts,fill=(38,42,32,50),width=2)
    if k in (2,3,4,9):
        for _ in range(60):
            x,y=rr.randrange(N),rr.randrange(N)
            d.line([(x,y),(x+rr.randrange(3,25),y+rr.randrange(-2,3))],fill=(190,182,145,rr.randrange(20,60)),width=rr.choice([1,1,2]))
        # Gravity-led grime is intentionally large enough to survive mipmaps.
        for _ in range(16):
            x,y=rr.randrange(N),rr.randrange(N)
            d.line([(x,y),(x+2,y+rr.randrange(25,110))],fill=(35,47,39,rr.randrange(12,32)),width=rr.randrange(2,6))
    if k==10:
        for pts in [[(10,90),(140,87),(240,90)],[(235,305),(405,300),(499,304)],[(36,385),(146,381)]]:d.line(pts,fill=(144,160,131,70),width=3)
    if k==13:
        d.rounded_rectangle((18,18,494,494),radius=8,outline=(66,90,83,255),width=14)
        # Authored drop pictogram, with no imported logos or typeface files.
        d.polygon([(256,55),(153,206),(128,253),(132,300),(155,336),(205,362),(256,369),(307,362),(357,331),(380,286),(370,239)],fill=(45,82,77,255))
        d.arc((170,205,325,326),20,88,fill=(182,177,140,255),width=12)
        # Original simple stencil strokes for 07, deliberately legible at close range.
        d.rectangle((177,397,232,458),outline=(52,69,61,255),width=9)
        d.line([(266,402),(327,402),(282,458)],fill=(52,69,61,255),width=10)
        for _ in range(55):
            x,y=rr.randrange(N),rr.randrange(N);d.line([(x,y),(x+rr.randrange(5,28),y+2)],fill=(113,96,65,100),width=2)
    if k==14:
        d.ellipse((45,45,467,467),fill=(184,183,149,255),outline=(31,46,42,255),width=22)
        for i in range(11):
            a=np.pi*(.15+i*.17);p=(256+int(np.cos(a)*166),256+int(np.sin(a)*166));q=(256+int(np.cos(a)*139),256+int(np.sin(a)*139));d.line([p,q],fill=(43,53,43,255),width=8)
        d.line([(256,256),(147,175)],fill=(110,50,39,255),width=12);d.ellipse((239,239,273,273),fill=(41,49,42,255))
    if k==15:
        for x in range(15,N,32):d.line([(x,10),(x,N-10)],fill=(86,98,82,255),width=9)
    gy,gx=np.gradient(h)
    nn=np.stack((-gx*.85,-gy*.85,np.full_like(gx,128)),axis=-1);nn/=np.linalg.norm(nn,axis=2,keepdims=True)
    norm=np.clip((nn*.5+.5)*255,0,255).astype(np.uint8)
    o=np.empty((N,N,3),np.uint8);o[:,:,0]=255;o[:,:,1]=np.clip(ROUGH[k]*255+h*.15,0,255);o[:,:,2]=int(METAL[k]*255)
    xy=(k%4*N,k//4*N);albedo.paste(tile,xy);orm.paste(Image.fromarray(o),xy);normal.paste(Image.fromarray(norm),xy)
for name,img in [('albedo',albedo),('orm',orm),('normal',normal)]:img.resize((1024,1024), Image.Resampling.LANCZOS).save(ROOT/'assets'/f'water_station_{name}.png')
print('Original 1024 × 1024 water-station PBR atlases generated.')
