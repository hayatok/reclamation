"""Original deterministic hand-authored PBR atlas; no third-party raster inputs."""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, random
from pathlib import Path
P=Path(__file__).resolve().parent.parent/'assets'; P.mkdir(exist_ok=True)
random.seed(809); rng=np.random.default_rng(809)
S=512; N=2048
# Industrial civilian colors, intentionally warm against the game's grey yard.
colors=['587982','a0603d','c0bca2','272925','786343','3c5a5e','b39c54','a99870','727975','853e31','ddcca0','252d2d','7a846a','8e6155','434b49','b6ad8b']
a=Image.new('RGB',(N,N));orm=Image.new('RGB',(N,N));normal=Image.new('RGB',(N,N),(128,128,255))
for i,c in enumerate(colors):
 b=np.array(tuple(bytes.fromhex(c)),float)
 small=Image.fromarray(rng.integers(0,255,(24,24),dtype=np.uint8)).resize((S,S),Image.Resampling.BICUBIC)
 mott=np.asarray(small,dtype=float)[...,None]/255*32-16
 arr=np.clip(b+rng.normal(0,1.8,(S,S,1))+mott,0,255).astype('uint8'); t=Image.fromarray(arr);d=ImageDraw.Draw(t)
 h=Image.new('L',(S,S),128);hd=ImageDraw.Draw(h)
 if i in [0,1,2,6,8,9,13,14,15]:
  # paint worn back to exposed oxide, scuffs, accumulated grime and rivet stains
  for k in range(460):
   x,y=random.randrange(S),random.randrange(S);w=random.choice([1,2,3,4,8]);hh=random.choice([1,2,3,7])
   col=random.choice([(88,63,41),(100,70,45),tuple((b*.7).astype(int)),tuple(np.minimum(255,b*1.22).astype(int))])
   d.ellipse((x,y,x+w,y+hh),fill=col);hd.ellipse((x,y,x+w,y+hh),fill=115)
  for k in range(125):
   x,y=random.randrange(S),random.randrange(S);d.line((x,y,min(S,x+random.randrange(3,65)),y+random.randrange(-2,3)),fill=tuple(np.minimum(255,b*1.2).astype(int)),width=1)
  for edge in range(13):
   q=(13-edge)/13
   d.rectangle((edge,edge,S-1-edge,S-1-edge),outline=tuple((b*(.52+edge*.024)).astype(int)))
  # intermittent rubbed paint edges
  for k in range(130):
   x=random.randrange(12,S-12);y=random.choice([random.randrange(5,14),random.randrange(S-14,S-5)])
   d.line((x,y,min(S-8,x+random.randrange(2,22)),y),fill=(157,143,111),width=1)
 elif i==3:
  for y in range(0,S,30):
   d.line((0,y,S,y+2),fill=(15,18,16),width=6);hd.line((0,y,S,y),fill=92,width=6)
   for x in range(-80,S,88): d.line((x,y,x+42,y+18),fill=(51,53,46),width=8)
 elif i==4:
  for x in range(0,S,6):
   col=(96+random.randrange(20),78+random.randrange(14),48+random.randrange(17));d.line((x,0,x+random.randrange(-5,6),S),fill=col,width=random.choice([1,2]));hd.line((x,0,x,S),fill=random.randrange(95,145),width=1)
  for y in [6,S-8]: d.line((0,y,S,y),fill=(48,44,32),width=5)
 elif i==5:
  # Opaque blue-grey reflected sky and long dragged dust marks.
  for y in range(S):
   f=y/S;col=(int(42+28*(1-f)),int(62+29*(1-f)),int(66+24*(1-f)))
   d.line((0,y,S,y),fill=col)
  d.polygon([(12,40),(50,40),(370,430),(315,430)],fill=(86,107,103))
  d.polygon([(200,0),(214,0),(S,330),(S,354)],fill=(80,99,95))
  for k in range(95):
   x,y=random.randrange(S),random.randrange(S);d.line((x,y,min(S,x+15),min(S,y+40)),fill=(59,75,69),width=1)
  d.rectangle((0,0,S-1,S-1),outline=(23,34,31),width=15)
 elif i in [7,12]:
  for x in range(0,S,4): d.line((x,0,x,S),fill=tuple(np.maximum(0,b-6).astype(int)));hd.line((x,0,x,S),fill=119,width=1)
  for y in range(0,S,5): d.line((0,y,S,y),fill=tuple(np.minimum(255,b+5).astype(int)));hd.line((0,y,S,y),fill=135,width=1)
  for y in [14,S-15]:
   d.line((0,y,S,y),fill=tuple((b*.62).astype(int)),width=4)
   for x in range(0,S,12):d.line((x,y-5,x+6,y-5),fill=(185,176,147),width=2)
 elif i==10:
  for x in range(0,S,18):d.line((x,0,x,S),fill=(158,144,108),width=2)
 elif i==11:
  for y in range(0,S,40):d.rectangle((0,y,S,y+16),fill=(53,62,56));hd.rectangle((0,y,S,y+16),fill=145)
 rough={3:238,5:75,8:135,10:97,11:175}.get(i,221 if i in [4,7,12] else 192)
 metallic=180 if i==8 else 70 if i in [0,1,2,6,9,13,14,15] else 0
 rougharr=np.asarray(h,dtype=float); yy,xx=np.gradient(rougharr)
 normals=np.stack([-xx*.35,-yy*.35,np.full((S,S),16)],axis=-1);normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
 nt=Image.fromarray(np.uint8(np.clip((normals*.5+.5)*255,0,255)))
 roughtex=np.uint8(np.clip(rough+(rougharr-128)*.13,0,255));ot=np.stack([np.full((S,S),255),roughtex,np.full((S,S),metallic)],axis=-1).astype('uint8')
 xy=((i%4)*S,(i//4)*S);a.paste(t,xy);orm.paste(Image.fromarray(ot),xy);normal.paste(nt,xy)
a.save(P/'survivor_vehicle_atlas.png',optimize=True);orm.save(P/'survivor_vehicle_orm.png',optimize=True);normal.save(P/'survivor_vehicle_normal.png',optimize=True)
print('VEHICLE_ATLAS_OK',N,N)
