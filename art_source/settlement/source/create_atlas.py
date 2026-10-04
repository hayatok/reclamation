"""Original RECLAMATION salvage material atlas. No external assets or fonts."""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, random
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
S=256; A=1024
random.seed(909); rng=np.random.default_rng(909)
# slate paint / red oxide / bare steel / aged timber / canvas / olive paint /
# rubber / brass / bone paint / soot / concrete / hazard stripes /
# old clay brick / dull green glass / ember / faded amber
colors=['526566','984e34','949e97','78604a','b5a27a','537e77','283231','b79856','d9d3b7','363e39','858373','b39b55','53432e','528243','bb643a','b9ad89']
albedo=Image.new('RGB',(A,A)); orm=Image.new('RGB',(A,A)); height=Image.new('L',(A,A))
for i,c in enumerate(colors):
 base=np.array(tuple(bytes.fromhex(c)),float)
 broad=Image.fromarray(rng.integers(0,255,(24,24),dtype=np.uint8)).resize((S,S),Image.Resampling.BICUBIC)
 fine=rng.normal(0,2.1,(S,S,1)); b=(np.asarray(broad)[...,None]/255-.5)*20
 tile=Image.fromarray(np.uint8(np.clip(base+b+fine,0,255)))
 h=Image.fromarray(np.uint8(np.clip(128+b[...,0]*1.3+rng.normal(0,2,(S,S)),0,255)))
 d=ImageDraw.Draw(tile); hd=ImageDraw.Draw(h)
 if i in (0,1,2,5,8,15):
  for n in range(440):
   x,y=random.randrange(S),random.randrange(S); r=random.randrange(1,5); length=random.randrange(2,22)
   col=(78,55,39) if n%3 else tuple(min(255,int(k*1.3)) for k in base)
   d.line((x,y,x+length,y+random.randrange(-2,3)), fill=col,width=r//2+1)
   hd.line((x,y,x+length,y),fill=103,width=r//2+1)
  if i!=2:
   for n in range(50):
    x,y=random.randrange(S),random.randrange(S);r=random.randrange(2,10)
    d.ellipse((x,y,x+r*3,y+r),fill=(105+random.randrange(18),71,47));hd.ellipse((x,y,x+r*3,y+r),fill=111)
 if i==3:
  for n in range(280):
   x,y=random.randrange(S),random.randrange(S); L=random.randrange(30,250)
   d.line((x,y,x+random.randrange(-3,4),y+L), fill=(random.randrange(62,101),random.randrange(49,70),40),width=random.choice([1,1,2]))
  for n in range(9):
   x,y=random.randrange(S),random.randrange(S)
   for rr in range(4,25,4):d.ellipse((x-rr*.35,y-rr,x+rr*.35,y+rr),outline=(79,62,42))
 if i==4:
  for x in range(0,S,4):d.line((x,0,x,S),fill=(147,132,106),width=1)
  for y in range(0,S,4):d.line((0,y,S,y),fill=(156,142,116),width=1)
 if i==10:
  for n in range(950):
   x,y=random.randrange(S),random.randrange(S);r=random.randrange(1,4)
   d.ellipse((x,y,x+r,y+r),fill=random.choice([(98,98,88),(139,135,117),(107,110,96)]))
 if i==11:
  for x in range(-S,S*2,128):d.polygon([(x,0),(x+58,0),(x+58-S,S),(x-S,S)],fill=(42,47,39))
  for n in range(150):
   x,y=random.randrange(S),random.randrange(S);d.line((x,y,x+random.randrange(5,30),y),fill=(120,115,90),width=2)
 if i==12:
  for n in range(500):
   x,y=random.randrange(S),random.randrange(S);d.point((x,y),fill=(99,70,55))
 metal=180 if i==2 else 130 if i in (0,1,5,7) else 0
 rough=180 if i in (2,7) else 204 if i in (0,5,8) else 237
 # All painted metals remain rough, with material response changing in chips.
 rr=np.full((S,S,3),(255,rough,metal),dtype=np.uint8);rr[:,:,1]=np.uint8(np.clip(rough+(np.asarray(broad,dtype=float)-128)*.10,0,255))
 p=((i%4)*S,(i//4)*S);albedo.paste(tile,p);orm.paste(Image.fromarray(rr),p);height.paste(h,p)
# Normal map from finite differences; hand-authored tiles use subtle amplitude.
f=np.asarray(height,dtype=float)/255;dx=np.roll(f,-1,axis=1)-np.roll(f,1,axis=1);dy=np.roll(f,-1,axis=0)-np.roll(f,1,axis=0)
n=np.stack((-dx*.8,dy*.8,np.ones_like(f)),axis=2);n/=np.linalg.norm(n,axis=2)[...,None];normal=Image.fromarray(np.uint8(np.clip((n*.5+.5)*255,0,255)))
for name,im in [('settlement_albedo',albedo),('settlement_orm',orm),('settlement_normal',normal)]:im.save(ROOT/'assets'/f'{name}.png',optimize=True)
print('Original 1024px PBR atlas generated')
