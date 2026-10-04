from PIL import Image,ImageDraw,ImageFilter
import numpy as np, random, os
random.seed(708); rng=np.random.default_rng(708)
from pathlib import Path
p=str(Path(__file__).resolve().parent.parent/'assets')
colors=['89937a','657054','b2b397','353f40','615447','25292b','7b4236','4a5553','42494a','675c4b','75493b','303533','525650','9d9179','c8baa0','26292a']
a=Image.new('RGB',(1024,1024)); orm=Image.new('RGB',(1024,1024),(255,220,0))
for i,c in enumerate(colors):
 base=np.array(tuple(bytes.fromhex(c)),float)
 noise=rng.normal(0,3,(256,256,1)); low=Image.fromarray(rng.integers(0,255,(16,16),dtype=np.uint8)).resize((256,256),Image.Resampling.BICUBIC)
 arr=np.asarray(low)[...,None]/255*24-12
 tile=Image.fromarray(np.uint8(np.clip(base+noise+arr,0,255))); d=ImageDraw.Draw(tile)
 for n in range(110):
  x,y=random.randrange(256),random.randrange(256); l=random.randrange(2,28)
  if i in [0,1,2,8,10,12]:
   col=tuple(int(z*.6) for z in base) if n%3 else (108,68,43)
   d.line((x,y,min(x+l,255),y+random.randrange(-2,3)),fill=col,width=random.choice([1,1,2]))
  elif i==4: d.line((x,y,x,min(y+l*3,255)),fill=(80,59,43),width=1)
 # grime pooling near panel edges with bright scuffed inner seam
 d.rectangle((1,1,254,254),outline=tuple(int(z*.63) for z in base),width=3)
 d.rectangle((5,5,250,250),outline=tuple(min(255,int(z*1.08)) for z in base),width=1)
 a.paste(tile,((i%4)*256,(i//4)*256)); metal=0; rough=180 if i in [0,8] else 235
 orm.paste(Image.new('RGB',(256,256),(255,rough,metal)),((i%4)*256,(i//4)*256))
a.save(p+'/infected_atlas.png',optimize=True);orm.save(p+'/infected_orm.png',optimize=True)
