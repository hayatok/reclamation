from PIL import Image, ImageDraw, ImageFilter
import numpy as np, random, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
N=512; rng=np.random.default_rng(41409)
base=[(102,108,101),(142,139,121),(43,49,47),(72,85,77),(103,75,52),(31,39,36),(62,70,64),(114,108,91)]
rough=[.94,.96,.95,.78,.92,.93,.74,.98]; metal=[0,0,0,.65,.3,.5,.75,0]
albedo=Image.new('RGB',(N*4,N*2)); orm=Image.new('RGB',(N*4,N*2)); normal=Image.new('RGB',(N*4,N*2))
for k,c in enumerate(base):
    low=Image.fromarray(rng.integers(0,256,(12,12),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(12))
    med=Image.fromarray(rng.integers(0,256,(70,70),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC)
    h=(np.asarray(low).astype(float)-128)*.16+(np.asarray(med).astype(float)-128)*.06+rng.normal(0,1.8,(N,N))
    a=np.clip(np.array(c)[None,None,:]+h[:,:,None],0,255).astype(np.uint8)
    if k in (3,4,6):
        # Broad desaturated oxidation islands; iron stays predominantly grey-green.
        m=np.asarray(low)/255.; patch=np.clip((m-.53)*4,0,.55)
        rust=np.array((105,75,47))
        a=np.clip(a*(1-patch[:,:,None])+rust*patch[:,:,None],0,255).astype(np.uint8)
    tile=Image.fromarray(a); d=ImageDraw.Draw(tile,'RGBA')
    rr=random.Random(788+k)
    for j in range(360 if k in (0,1,2,7) else 160):
        x,y=rr.randrange(N),rr.randrange(N); r=rr.choice((1,1,2,3,4)); v=rr.randrange(30,160)
        d.polygon([(x-r,y),(x,y-r),(x+r,y+1),(x+1,y+r)], fill=(v,v, int(v*.94),rr.randrange(15,42)))
    if k in (0,1,2):
        for j in range(9):
            x,y=rr.randrange(N),rr.randrange(N); pts=[(x,y)]
            for t in range(rr.randrange(3,8)):
                x+=rr.randrange(-18,27); y+=rr.randrange(10,28); pts.append((x,y))
            d.line(pts,fill=(21,29,25,55),width=2)
    if k==3:
        for y in (94,257,438): d.line([(0,y),(N,y-6)],fill=(143,143,118,30),width=2)
        # surviving tiny grey municipal-coating islands, no bright safety orange
    if k in (3,4,6):
        for j in range(48):
            x,y=rr.randrange(N),rr.randrange(N)
            d.line([(x,y),(x+rr.randrange(5,36),y+rr.randrange(-2,3))],fill=(138,135,107,45),width=1)
    gy,gx=np.gradient(h)
    nn=np.stack((-gx*.9,-gy*.9,np.full_like(gx,128)),axis=-1); nn=nn/np.linalg.norm(nn,axis=2,keepdims=True)
    norm=np.clip((nn*.5+.5)*255,0,255).astype(np.uint8)
    o=np.empty((N,N,3),np.uint8); o[:,:,0]=255; o[:,:,1]=np.clip(rough[k]*255+h*.2,0,255); o[:,:,2]=int(metal[k]*255)
    xy=((k%4)*N,(k//4)*N); albedo.paste(tile,xy); orm.paste(Image.fromarray(o),xy); normal.paste(Image.fromarray(norm),xy)
for name,img in [('albedo',albedo),('orm',orm),('normal',normal)]: img.save(ROOT/'assets'/f'street_salvage_{name}.png')
print('Original deterministic street salvage atlas generated: 2048x1024, eight material zones.')
