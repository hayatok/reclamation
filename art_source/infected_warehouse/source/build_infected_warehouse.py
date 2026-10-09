"""Original RECLAMATION warehouse infestation, deterministic indexed mesh authoring.

Run with Python 3 + numpy + Pillow. No Blender, downloaded assets or mesh packages.
Metres, Godot/glTF +Y up; the loading openings face -X and +Z.
"""
import argparse, hashlib, json, math, struct
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TAU = math.tau
WALL = '#969a85'
PALE = '#b0b09a'
DARK = '#535d54'
BRICK = '#866554'
STEEL = '#606b61'
RUST = '#856349'
SOOT = '#282e28'

def color(code):
    v = np.array([int(code[i:i+2],16)/255 for i in (1,3,5)])
    return np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)

def unit(v):
    v=np.array(v,dtype=float);return v/max(np.linalg.norm(v),1e-12)

class Mesh:
    def __init__(self,name):
        self.name=name;self.v=[];self.c=[];self.uv=[];self.mask=[];self.f=[]
    def vertex(self,p,c,uv=(0,0),mask=0):
        self.v.append(list(p));self.c.append(list(color(c) if isinstance(c,str) else c)+[1]);self.uv.append(list(uv));self.mask.append([mask,0]);return len(self.v)-1
    def face(self,ids):
        for i in range(1,len(ids)-1):self.f.append([ids[0],ids[i],ids[i+1]])
    def polygon(self,points,c):
        self.face([self.vertex(p,c,(p[0]*.48,p[2]*.48)) for p in points])
    def box(self,p,d,c,rot=(0,0,0)):
        rx,ry,rz=rot
        ax=np.array([[1,0,0],[0,math.cos(rx),-math.sin(rx)],[0,math.sin(rx),math.cos(rx)]])
        ay=np.array([[math.cos(ry),0,math.sin(ry)],[0,1,0],[-math.sin(ry),0,math.cos(ry)]])
        az=np.array([[math.cos(rz),-math.sin(rz),0],[math.sin(rz),math.cos(rz),0],[0,0,1]])
        r=az@ay@ax
        q=[np.array(p)+r@(np.array(v)*np.array(d)*.5) for v in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        for ids in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]:self.polygon([q[i] for i in ids],c)
    def wall(self,profile,axis,at,thickness,c):
        # Extruded polygon with intentionally torn crown, rather than stacked boxes.
        sides=[]
        for side in [-1,1]:
            ring=[]
            for u,y in profile:
                p=(u,y,at+side*thickness/2) if axis=='x' else (at+side*thickness/2,y,u)
                ring.append(p)
            sides.append(ring)
        # These wall profiles are x/y monotonic, cap triangulation uses a basal fan.
        if axis=='x':self.polygon(sides[0][::-1],c);self.polygon(sides[1],c)
        else:self.polygon(sides[0],c);self.polygon(sides[1][::-1],c)
        n=len(profile)
        for i in range(n):
            j=(i+1)%n
            pts=[sides[0][i],sides[0][j],sides[1][j],sides[1][i]]
            if axis=='z':pts.reverse()
            self.polygon(pts,PALE if i not in [0,n-1] else c)
    def tube(self,points,radii,c,segments=8):
        rings=[]
        for k,(p,r) in enumerate(zip(points,radii)):
            tangent=unit(np.array(points[min(k+1,len(points)-1)])-np.array(points[max(k-1,0)]))
            a=unit(np.cross(tangent,[0,1,0] if abs(tangent[1])<.9 else [1,0,0]));b=np.cross(tangent,a)
            ring=[]
            for i in range(segments):
                t=i*TAU/segments
                ring.append(self.vertex(np.array(p)+r*(math.cos(t)*a+math.sin(t)*b),c,(i/segments,k*.3)))
            rings.append(ring)
        for k in range(len(rings)-1):
            for i in range(segments):
                j=(i+1)%segments;self.face([rings[k][i],rings[k+1][i],rings[k+1][j],rings[k][j]])
        self.face(rings[0][::-1]);self.face(rings[-1])
    def arrays(self):
        v=np.array(self.v,dtype=np.float32);f=np.array(self.f,dtype=np.uint32)
        n=np.zeros_like(v)
        for face in f:
            a,b,c=v[face];cross=np.cross(b-a,c-a)
            for i in face:n[i]+=cross
        n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-12)
        return v,n,np.array(self.c,dtype=np.float32),np.array(self.uv,dtype=np.float32),np.array(self.mask,dtype=np.float32),f

def roof(mesh,x0,x1,z0,z1,y,broken=True):
    # Open torn edge and rolled corrugated metal in one indexed surface.
    nx=18;nz=5;rings=[]
    for j in range(nz+1):
        line=[]
        for i in range(nx+1):
            t=i/nx;s=j/nz;x=x0+(x1-x0)*t;z=z0+(z1-z0)*s
            x+=(.20*math.sin(j*2.9)+.11*math.cos(j*5.4))*t**5 if broken else 0
            h=y-.10*(x-x0)+(.055 if i%2 else -.055)-.035*math.sin(s*math.pi)
            if broken:h+=.21*t**5*math.sin(j*2.4)
            line.append(mesh.vertex((x,h,z),STEEL,(t*2,s*2)))
        rings.append(line)
    for j in range(nz):
        for i in range(nx):mesh.face([rings[j][i],rings[j+1][i],rings[j+1][i+1],rings[j][i+1]])
    # Thin underside does not depend on transparency or disabled culling.
    count=len(mesh.f)
    start=(len(mesh.v)-(nx+1)*(nz+1));end=len(mesh.v)
    for idx in range(start,end):
        p=np.array(mesh.v[idx]);p[1]-=.05;mesh.vertex(p,DARK,mesh.uv[idx])
    off=end-start
    for face in list(mesh.f)[count-nx*nz*2:]:mesh.f.append([idx+off for idx in face[::-1]])

def shell(dead=False):
    b=Mesh('WarehouseShell' if not dead else 'BrokenWarehouse')
    b.box((0,.08,0),(6.35,.16,5.7),DARK)
    b.box((0,.18,0),(5.98,.06,5.3),SOOT)
    if dead:
        b.wall([(-3.05,.18),(-.85,.18),(-.85,.59),(-1.17,.87),(-1.43,.74),(-1.68,1.33),(-2.21,1.12),(-2.56,1.41),(-3.05,1.11)],'x',-2.6,.30,BRICK)
        b.wall([(-2.7,.18),(-1.1,.18),(-1.1,.68),(-1.43,.90),(-2.12,.69),(-2.7,1.15)],'z',-3,.3,WALL)
        for i in range(9):
            b.box((-2.24+(i%3)*1.93,.34+(i%2)*.14,-1.65+(i//3)*1.5),(.88,.31,.74),BRICK if i%2 else WALL,(.12,i*.59,.09))
        for p,d,r in [((-1.3,.48,-.6),(2.55,.17,1.8),(.19,.33,.12)),((.6,.65,.4),(2.7,.25,1.4),(-.18,-.24,-.15)),((-.95,.36,1.72),(2.15,.2,.8),(.09,.31,.13))]:b.box(p,d,DARK,r)
        roof(b,-2.45,-.55,-1.83,.78,.76)
        b.box((1.65,.5,-1.1),(.12,.12,2.8),RUST,(0,.37,.21))
        return b
    b.wall([(-3.1,.16),(3.12,.16),(3.12,2.25),(2.7,2.5),(2.23,3.69),(1.68,3.42),(1.2,3.76),(.87,3.17),(.36,3.43),(-.19,4.25),(-.62,4.13),(-.94,4.56),(-1.7,4.69),(-2.13,4.42),(-2.51,4.7),(-3.1,4.22)],'x',-2.6,.32,WALL)
    b.wall([(-2.6,.16),(-1.31,.16),(-1.31,3.86),(-1.52,4.2),(-1.99,4.06),(-2.35,4.41),(-2.6,4.2)],'z',-3,.34,BRICK)
    b.wall([(1.35,.16),(2.62,.16),(2.62,2.65),(2.2,2.83),(1.89,2.53),(1.65,2.87),(1.35,2.64)],'z',-3,.34,WALL)
    b.box((-3,3.04,.02),(.39,.41,2.75),DARK,(.03,0,.035))
    b.box((-3.04,1.53,-1.3),(.44,3.05,.17),WALL)
    b.box((-3.04,1.26,1.3),(.44,2.5,.17),PALE)
    # Shutter crushed against inside jamb, true opening remains clear.
    for z in [-.96,-.79,-.62,-.45]:b.box((-2.75,1.0,z),(.065,1.48,.13),RUST,(.2,.28,-.10))
    b.wall([(-3.1,.16),(-1.53,.16),(-1.53,2.69),(-1.79,2.84),(-2.01,2.63),(-2.38,2.97),(-2.6,2.79),(-3.1,2.68)],'x',2.59,.34,BRICK)
    b.box((-1.46,1.5,2.59),(.28,3,.44),WALL)
    b.box((1.36,1.28,2.59),(.27,2.56,.44),DARK)
    b.box((-.03,2.8,2.6),(2.8,.32,.4),WALL,(0,0,-.115))
    b.wall([(1.56,.16),(3.13,.16),(3.13,.6),(2.76,.95),(2.35,.82),(2.11,1.34),(1.83,1.03),(1.56,1.2)],'x',2.6,.34,WALL)
    b.wall([(-2.65,.16),(2.6,.16),(2.6,.57),(2.06,.96),(1.53,.77),(1.21,1.1),(.91,.93),(.56,1.66),(.2,1.46),(-.1,1.8),(-.51,1.54),(-.8,2.1),(-1.22,2.06),(-1.54,3.44),(-1.87,3.59),(-2.14,3.36),(-2.65,3.89)],'z',3.01,.32,BRICK)
    # Masonry pilasters, lintel and faded loading-bay numeral-like stripes.
    for x,h in [(-2.77,4.36),(-1.8,4.42),(-.63,3.97),(2.74,2.47)]:b.box((x,h/2,-2.41),(.14,h,.15),DARK)
    for x in [-2.77,-2.27]:b.box((x,1.76,2.769),(.36,.88,.02),SOOT)
    b.box((-2.42,2.29,2.775),(1.37,.16,.05),PALE)
    for x in [-.69,.69]:b.box((x,.22,2.70),(.78,.015,.13),PALE)
    roof(b,-2.95,-1.02,-2.55,2.50,4.19)
    for z in [-2.2,-.9,.49,1.94]:b.box((-1.94,4.22,z),(2.03,.11,.11),RUST,(0,0,-.10))
    b.box((-1.26,3.63,-.84),(.11,.12,3.6),RUST,(.24,.07,.41))
    b.box((1.79,3.63,-2.13),(1.8,.12,.8),STEEL,(.27,0,-.29))
    b.box((-.42,1.04,-.45),(1.79,.15,2.48),DARK,(.27,.2,-.42))
    # Just a few larger masonry chips, kept within the foundation.
    for i in range(8):b.box((-2.54+i*.72,.3,1.8+.16*(i%3)),(.37+.15*(i%2),.25,.37),BRICK if i%2 else PALE,(.11,.48*i,.12))
    return b

def mantle(dead=False):
    b=Mesh('Infection' if not dead else 'SpentInfection')
    n=48
    # Contiguous outer-to-inner rings create a genuine recess and one fused mass.
    # Sharply alternating shoulder widths create fibrous strata, never smooth spheres.
    profiles=[(.25,1.4),(.43,1.32),(.7,.93),(1.1,.89),(1.5,.97),(1.86,1.07),(2.13,1.42),(2.29,1.18),(2.58,1.2),(2.87,1.61),(3.05,1.28),(3.38,1.40),(3.68,1.69),(3.85,1.46),(4.12,1.35),(4.33,1.21),(4.41,.99),(4.2,.83),(3.77,.72),(3.45,.55),(3.13,.27),(3.02,.03)]
    rings=[]
    for k,(height,radius) in enumerate(profiles):
        ring=[]
        for i in range(n):
            t=i*TAU/n;u=height/4.41
            grain=math.sin(12*t+u*1.8)*.055+math.sin(7*t-u*2.1)*.042
            lobes=.15*math.sin(3*t+.8)+.075*math.sin(5*t-.7)
            r=radius*(1+lobes+grain)
            # A sweeping triangular buttress is fused into the eastern side, clear of south door.
            foot=(max(0,math.cos(t-.08))**12)*max(0,1-height/1.15)*1.03
            r+=foot
            cx=.66+.28*math.sin(u*2.3);cz=-.34-.12*math.sin(u*3.0)
            x=cx+r*math.cos(t);z=cz+r*.86*math.sin(t)
            h=height+.16*math.sin(3*t+.7)*min(1,height)+.10*math.sin(7*t+.2)*min(1,height)
            h+=max(0,(height-2.6)/1.81)*(.48*math.cos(t+2.37)+.16*math.sin(2*t))
            # Deep ruptured front lip: diagonal slit, not a symmetrical vase.
            h-=.42*max(0,math.cos(t-.86))**8*max(0,(height-3.6)/.81)
            inner=k>=17
            ridge=max(0,math.sin(12*t+u*1.8))
            outer=np.array(color('#81704e'))*(.78+.20*ridge+.11*math.sin(3*t+u*4))
            if k in [6,9,12,15,16]:outer=np.array(color('#a09367'))*(.87+.13*ridge)
            if inner:outer=color('#3e3024')*(.48+.52*max(0,(height-3.0)/1.4))
            if k>=19:outer=color('#211c17')
            if dead:
                h=.18+max(0,h-.2)*.22;x=.3+(x-.3)*1.07;z=.25+(z-.25)*1.06
                outer=color('#5d5742')*(.73+.16*ridge)
                if inner:outer=color('#292820')
            ring.append(b.vertex((x,h,z),outer,(i/n*3.4,height*.5),(.6 if k==17 else 1 if k>=18 else 0)))
        rings.append(ring)
    for k in range(len(rings)-1):
        for i in range(n):
            j=(i+1)%n
            b.face([rings[k][i],rings[k+1][i],rings[k+1][j],rings[k][j]])
    b.face(rings[-1][::-1]);b.face(rings[0])
    # Fibrous buttresses crawl down masonry; wide base into the same mantle.
    roots=[([(1.93,2.7,.11),(2.65,1.65,.37),(3.12,.5,.71),(3.75,.16,1.13)],[.26,.22,.16,.025]),
           ([(.7,1.65,-1.02),(.18,.61,-1.81),(-.38,.2,-2.7),(-.88,.13,-3.52)],[.29,.25,.13,.02]),
           ([(-.3,2.3,.05),(-.7,1.25,.25),(-1.63,.36,.49),(-2.51,.14,.42)],[.30,.23,.11,.025]),
           ([(1.75,1.43,.95),(2.23,.69,1.87),(2.71,.15,2.66)],[.26,.18,.025])]
    for points,radii in roots:
        if dead:points=[(x,.13+(y-.13)*.2,z) for x,y,z in points];radii=[r*.67 for r in radii]
        b.tube(points,radii,'#756444' if not dead else '#514b39',8)
    return b

def export(path,meshes):
    blob=bytearray();views=[];accessors=[];gmeshes=[]
    def pack(a,type_,component=5126):
        nonlocal blob
        while len(blob)%4:blob.append(0)
        a=np.asarray(a,dtype=np.float32 if component==5126 else np.uint32)
        offset=len(blob);data=a.tobytes();blob.extend(data)
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data)})
        ac={'bufferView':len(views)-1,'componentType':component,'count':len(a),'type':type_}
        if type_=='VEC3':ac['min']=a.min(axis=0).tolist();ac['max']=a.max(axis=0).tolist()
        accessors.append(ac);return len(accessors)-1
    result={}
    for m in meshes:
        v,n,c,uv,mask,f=m.arrays()
        attrs={key:pack(val,type_) for key,val,type_ in [('POSITION',v,'VEC3'),('NORMAL',n,'VEC3'),('COLOR_0',c,'VEC4'),('TEXCOORD_0',uv,'VEC2'),('TEXCOORD_1',mask,'VEC2')]}
        idx=pack(f.flatten(),'SCALAR',5125)
        gmeshes.append({'name':m.name,'primitives':[{'attributes':attrs,'indices':idx,'material':0,'mode':4}]})
        result[m.name]={'triangles':len(f),'vertices':len(v),'surfaces':1,'aabb_min':v.min(axis=0).tolist(),'aabb_max':v.max(axis=0).tolist(),'horizontal_radius':float(np.linalg.norm(v[:,[0,2]],axis=1).max())}
    doc={'asset':{'version':'2.0','generator':'RECLAMATION original indexed warehouse generator'},'scene':0,'scenes':[{'nodes':list(range(len(meshes)))}],'nodes':[{'name':m.name,'mesh':i} for i,m in enumerate(meshes)],'meshes':gmeshes,'materials':[{'name':'Opaque vertex linear','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.98},'alphaMode':'OPAQUE','doubleSided':False}],'buffers':[{'byteLength':len(blob)}],'bufferViews':views,'accessors':accessors}
    j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
    blob+=b'\0'*((-len(blob))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(blob))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(blob),0x004e4942)+blob)
    return result

def texture(path):
    # Compact original grayscale bark/fibre modulation; all stochastic input seeded.
    rng=np.random.default_rng(10092026);size=256;y,x=np.mgrid[0:size,0:size]
    fibres=np.sin(x*.31+np.sin(y*.026)*1.7+np.sin(y*.09)*.3)
    broad=np.sin(x*.043+y*.027)*np.cos(y*.051-x*.013)
    value=np.clip(204+fibres*11+broad*14+rng.normal(0,5,(size,size)),152,238).astype(np.uint8)
    Image.fromarray(np.stack([value]*3,axis=2)).save(path,optimize=True)

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output-dir',type=Path,default=ROOT);args=ap.parse_args();out=args.output_dir.resolve();assets=out/'assets';assets.mkdir(parents=True,exist_ok=True)
    stats={}
    for state in ['alive','dead']:
        ms=[shell(state=='dead'),mantle(state=='dead')]
        stats[state]=export(assets/('infected_warehouse_'+state+'.glb'),ms)
        total=sum(s['triangles'] for s in stats[state].values());assert total<=6000,total
        assert max(s['horizontal_radius'] for s in stats[state].values())<=4.5
    texture(assets/'infected_fibre.png')
    stats['provenance']={'original':True,'source':'source/build_infected_warehouse.py','coordinate_system':'glTF +Y up, metres','vertex_colors':'linear RGB, converted explicitly from authored sRGB hex','texture':'Original deterministic 256x256 grayscale fibre field; mipmaps required at import','runtime_surfaces_per_visible_state':2}
    (out/'asset_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    print(json.dumps(stats,indent=2))

if __name__=='__main__':main()
