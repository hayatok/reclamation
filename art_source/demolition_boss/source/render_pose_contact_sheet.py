"""Small CPU-only geometric contact sheet for the baked pose contract."""
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from validate_boss_glb import read_glb, array

ROOT=Path(__file__).resolve().parent.parent


def main():
    g,blob=read_glb(ROOT/'generated/demolition_boss_near.glb')
    nodes={n['name']:n for n in g['nodes'] if 'mesh' in n}
    poses=['idle_00','walk_03','walk_09','windup_00','windup_04','windup_08',
           'windup_10','windup_11','recovery_00','recovery_04','death_05','death_09']
    atlas=Image.open(ROOT/'generated/demolition_boss_atlas.png').convert('RGB')
    canvas=Image.new('RGB',(1200,1200),(37,43,45));draw=ImageDraw.Draw(canvas)
    eye=np.array([3.,2.3,-4.]);eye/=np.linalg.norm(eye)
    right=np.cross(eye,[0.,1.,0.]);right/=np.linalg.norm(right)
    up=np.cross(right,eye)
    lamp=np.array([-.3,.8,-.4]);lamp/=np.linalg.norm(lamp)
    for cell,name in enumerate(poses):
        cx,cy=(cell%3)*400,(cell//3)*300
        draw.rectangle((cx+4,cy+4,cx+396,cy+296),fill=(51,58,59))
        p=g['meshes'][nodes[name]['mesh']]['primitives'][0];a=p['attributes']
        pos=array(g,blob,a['POSITION']);uv=array(g,blob,a['TEXCOORD_0'])
        idx=array(g,blob,p['indices']).reshape(-1,3)
        pivot=[0,.45,-.65] if name.startswith('death') else [0,1.05,0]
        pts=pos-np.array(pivot);screen=np.column_stack((pts@right,-pts@up))*112
        screen+=np.array([cx+200,cy+145]);depth=pos@eye
        for tri in sorted(idx,key=lambda ids:float(depth[ids].mean())):
            pts3=pos[tri];normal=np.cross(pts3[1]-pts3[0],pts3[2]-pts3[0])
            norm=np.linalg.norm(normal)
            if norm<1e-9:continue
            normal/=norm
            if np.dot(normal,eye)<0:continue
            tex=uv[tri].mean(axis=0)
            col=atlas.getpixel((min(511,int(tex[0]*512)),min(511,int(tex[1]*512))))
            shade=.40+.60*max(0,float(normal@lamp))
            draw.polygon([tuple(v) for v in screen[tri]],fill=tuple(int(c*shade) for c in col))
        draw.text((cx+15,cy+277),name,fill=(229,232,226))
    path=ROOT/'review/pose_contact_sheet.png';canvas.save(path)
    print(path)


if __name__=='__main__':main()
