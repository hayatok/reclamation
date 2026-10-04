from PIL import Image
import numpy as np
from scipy.ndimage import gaussian_filter
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/fx';out.mkdir(exist_ok=True)
n=256;rng=np.random.default_rng(713907)
y,x=np.mgrid[-1:1:complex(n),-1:1:complex(n)];r=np.sqrt(x*x+y*y);a=np.arctan2(y,x)
noise=gaussian_filter(rng.random((n,n)),4);noise=(noise-noise.min())/(noise.max()-noise.min())
fine=gaussian_filter(rng.random((n,n)),1);fine=(fine-fine.min())/(fine.max()-fine.min())
def save(name,col,alpha):
 ar=np.zeros((n,n,4));ar[:,:,:3]=col;ar[:,:,3]=np.clip(alpha,0,1)
 Image.fromarray(np.uint8(np.clip(ar,0,1)*255),'RGBA').save(out/(name+'.png'))
edge=.64+.09*np.sin(a*5+1)+.075*np.cos(a*9)+.13*(noise-.5)
d=np.maximum(0,1-r/edge)
col=np.stack([np.ones_like(r),.25+.73*np.clip(d*1.8,0,1),.055+.72*np.clip(d*2.6-1,0,1)],axis=-1)
save('flame',col,np.clip(d*5,0,1)*(.68+.32*fine))
star=.20+.60*np.maximum(0,np.cos(a*4))**18
alpha=np.maximum(np.clip((star-r)*12,0,1),np.exp(-r*r*32))
save('flash',np.stack([np.ones_like(r),.87+.1*np.exp(-r*5),.55+.4*np.exp(-r*8)],axis=-1),alpha)
edge=.69+.1*np.sin(a*5)+.1*(noise-.5);d=np.clip(1-r/edge,0,1)
c=.28+.25*noise
save('smoke',np.stack([c*.93,c,c*1.05],axis=-1),np.clip(d*2,0,1)*(.45+.5*noise))
ring=np.exp(-((r-(.66+.022*np.sin(a*19)+.018*noise))/.035)**2)
save('shock',np.ones((n,n,3)),ring*(.5+.5*fine))
edge=.7+.08*np.sin(a*7)+.08*(noise-.5);d=np.clip(1-r/edge,0,1)
c=.12+.10*noise
save('scorch',np.stack([c,c*.84,c*.67],axis=-1),d*.75*(.7+.3*fine))
