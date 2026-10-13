"""Authored live damage stage for RECLAMATION's original infected warehouse.

Run: python source/build_infected_warehouse_damaged.py --output-dir .
Requires Python 3, numpy and Pillow, as the original generator does.
The unchanged build_infected_warehouse.py must remain next to this file.
The generated GLB is the <= 50% HP live stage, never the destroyed stage.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import build_infected_warehouse as base

BASE_SHA256 = '74699f8fc611240bb60acbc76c5c3f69cc269862a3dd7c52b7a56024e40f7981'
ROOT = Path(__file__).resolve().parent.parent


def damaged_shell():
    """Retain the identity and gates; remove the large near roof/wall bay."""
    b = base.Mesh('WarehouseShell')
    b.box((0, .08, 0), (6.35, .16, 5.7), base.DARK)
    b.box((0, .18, 0), (5.98, .06, 5.3), base.SOOT)
    # Rear wall retains two tall piers, with a deep, wide new central breach.
    b.wall([(-3.1,.16),(3.12,.16),(3.12,2.25),(2.7,2.5),
            (2.23,3.69),(1.68,3.42),(1.2,3.76),(.94,3.07),
            (.48,2.77),(.13,2.05),(-.24,2.34),(-.62,2.01),
            (-.94,2.72),(-1.29,2.58),(-1.72,4.22),
            (-2.13,4.42),(-2.51,4.7),(-3.1,4.22)],
           'x', -2.6, .32, base.WALL)
    b.wall([(-2.6,.16),(-1.31,.16),(-1.31,3.86),(-1.52,4.2),
            (-1.99,4.06),(-2.35,4.41),(-2.6,4.2)],
           'z', -3, .34, base.BRICK)
    # Foreground outer pier is torn down to 1.4 m instead of 2.9 m.
    b.wall([(1.35,.16),(2.62,.16),(2.62,.64),(2.30,.91),
            (2.05,.72),(1.87,1.23),(1.61,1.07),(1.35,1.40)],
           'z', -3, .34, base.WALL)
    # Both original gate clearances and their coordinates are retained.
    b.box((-3,3.04,.02),(.39,.41,2.75),base.DARK,(.03,0,.035))
    b.box((-3.04,1.53,-1.3),(.44,3.05,.17),base.WALL)
    b.box((-3.04,1.26,1.3),(.44,2.5,.17),base.PALE)
    for z in [-.96,-.79,-.62,-.45]:
        b.box((-2.75,1.0,z),(.065,1.48,.13),base.RUST,(.2,.28,-.10))
    # The front masonry bay is split and substantially lower, not rescaled.
    b.wall([(-3.1,.16),(-1.53,.16),(-1.53,.72),(-1.76,1.05),
            (-2.02,.63),(-2.34,.86),(-2.52,1.44),(-2.77,1.31),
            (-3.1,1.54)], 'x', 2.59, .34, base.BRICK)
    b.box((-1.46,1.5,2.59),(.28,3,.44),base.WALL)
    b.box((1.36,1.28,2.59),(.27,2.56,.44),base.DARK)
    b.box((-.03,2.8,2.6),(2.8,.32,.4),base.WALL,(0,0,-.115))
    b.wall([(1.56,.16),(3.13,.16),(3.13,.6),(2.76,.95),
            (2.35,.82),(2.11,1.34),(1.83,1.03),(1.56,1.2)],
           'x',2.6,.34,base.WALL)
    b.wall([(-2.65,.16),(2.6,.16),(2.6,.57),(2.06,.96),
            (1.53,.77),(1.21,1.1),(.91,.93),(.56,1.27),
            (.20,1.10),(-.1,1.62),(-.51,1.40),(-.8,2.1),
            (-1.22,2.06),(-1.54,3.44),(-1.87,3.59),
            (-2.14,3.36),(-2.65,3.89)],'z',3.01,.32,base.BRICK)
    for x,h in [(-2.77,4.36),(-1.8,3.92),(-.63,1.89),(2.74,2.47)]:
        b.box((x,h/2,-2.41),(.14,h,.15),base.DARK)
    # Surviving painted loading markings, interrupted by the new break.
    for x in [-2.77,-2.27]:
        b.box((x,.65,2.769),(.36,.70,.02),base.SOOT)
    for x in [-.69,.69]:
        b.box((x,.22,2.70),(.78,.015,.13),base.PALE)
    # Only 38% of the original high roof remains. Torn, rolled edge and
    # fallen corrugated slab occupy different heights and orientations.
    base.roof(b,-2.95,-1.02,-2.55,-.63,4.19)
    for z in [-2.20,-.90]:
        b.box((-1.94,4.22,z),(2.03,.11,.11),base.RUST,(0,0,-.10))
    folded = base.Mesh('folded')
    base.roof(folded,-2.72,-1.16,-.57,1.58,2.79)
    for v in folded.v:
        # A large single folded sheet hangs into the missing bay. This is
        # a local buckled collapse, with the intact rear roof unmodified.
        s = (v[2] + .57) / 2.15
        v[1] -= 1.78 * s + .32 * math.sin(s * math.pi)
        v[0] += .19 * math.sin(s * math.pi)
    append_mesh(b, folded)
    # Torn roof edge: upward-bent lip and exposed diagonal purlin.
    b.box((-2.02,3.86,-.51),(1.98,.12,.30),base.STEEL,(.51,0,-.10))
    b.tube([(-2.78,4.04,-.51),(-2.39,2.74,.61),(-1.93,.76,1.52)],
           [.075,.075,.075],base.RUST,4)
    b.box((-1.26,3.63,-1.67),(.11,.12,1.81),base.RUST,(.24,.07,.41))
    b.box((1.79,3.63,-2.13),(1.8,.12,.8),base.STEEL,(.27,0,-.29))
    b.box((-.42,1.04,-.45),(1.79,.15,2.48),base.DARK,(.27,.2,-.42))
    # Large broken masonry lies within the foundation, outside both gates.
    rubble = [((-2.67,.37,1.92),(.77,.43,.59),(.14,.26,.19)),
              ((-2.15,.44,1.63),(.93,.52,.59),(.23,-.32,-.15)),
              ((-1.97,.29,2.06),(.49,.25,.45),(.10,.7,.12)),
              ((-.72,.37,-1.97),(.82,.46,.61),(.21,.3,-.16)),
              ((.15,.29,-2.09),(.59,.28,.55),(.16,-.4,.19))]
    for i,(p,d,r) in enumerate(rubble):
        b.box(p,d,base.BRICK if i%2 else base.PALE,r)
    return b


def append_mesh(target, source):
    offset = len(target.v)
    for attr in ['v','c','uv','mask']:
        getattr(target,attr).extend(getattr(source,attr))
    target.f.extend([[i+offset for i in f] for f in source.f])


def damaged_mantle():
    """Excise a 97.5-degree upper crown wedge and author its torn interior."""
    b = base.mantle(False)
    n, cut_ring, start, end = 48, 8, 3, 16
    # Lower the inner cavity's floor, retaining the UV2 live-emission mask.
    # The rest of the live column, including all roots, remains full size.
    for k in range(18,22):
        for i in range(n):
            b.v[k*n+i][1] -= .48 + .18*(k-18)/3
    # Remove angular quads from the outer shoulder through the inner bowl.
    # Original mantle is 21 strips of 48 quads, before floor caps/roots.
    faces = []
    for k in range(21):
        for i in range(n):
            if k >= cut_ring and start <= i < end:
                continue
            at = 2*(k*n+i)
            faces.extend(b.f[at:at+2])
    faces.extend(b.f[21*n*2:])
    b.f = faces
    # A broken fibrous shelf connects the remaining shoulder to the cavity.
    # Jagged radial intermediate points provide real saw-toothed geometry.
    ridge, cavity = [], []
    for i in range(start,end+1):
        p = np.array(b.v[cut_ring*n+i])
        p[1] += [.02,-.12,.13,-.21,.08,-.17][(i-start)%6]
        p[0] += .10*math.sin(i*2.8)
        p[2] += .10*math.cos(i*2.2)
        ridge.append(b.vertex(p,'#a09367',(i/n*3.4,p[1]*.5),.40))
        q = np.array(b.v[21*n+i])
        # A broad, dark open wound stays visibly alive through its mask.
        cavity.append(b.vertex(q,'#3e3024',(i/n*3.4,q[1]*.5),1.0))
    for j,i in enumerate(range(start,end)):
        outer0, outer1 = cut_ring*n+i, cut_ring*n+i+1
        b.face([outer0,ridge[j],ridge[j+1],outer1])
        b.face([ridge[j],cavity[j],cavity[j+1],ridge[j+1]])
    # Author opaque cross sections at both vertical torn edges. Each cap
    # follows the original thick profile, never an alpha-cutout billboard.
    for i,reverse in [(start,False),(end,True)]:
        edge = [b.v[k*n+i] for k in range(cut_ring,22)]
        root = np.array(b.v[21*n+i])
        for j in range(len(edge)-2):
            pts=[edge[j],edge[j+1],root]
            if reverse:
                pts.reverse()
            ids=[b.vertex(p,'#81704e',(i/n*3.4,p[1]*.5),.55)
                 for p in pts]
            b.face(ids)
    # Two visibly peeled fibres hang from the wound; roots remain original.
    b.tube([(2.02,3.53,.24),(2.51,2.66,.50),(2.63,1.92,.69)],
           [.17,.14,.04],'#a09367',6)
    b.tube([(.19,3.71,.91),(-.12,3.06,1.28),(.14,2.41,1.38)],
           [.15,.11,.035],'#756444',6)
    # Discard unused removed-sector vertices; preserve baked attributes.
    used=sorted({idx for face in b.f for idx in face})
    remap={old:new for new,old in enumerate(used)}
    for attr in ['v','c','uv','mask']:
        values=getattr(b,attr)
        setattr(b,attr,[values[i] for i in used])
    b.f=[[remap[i] for i in f] for f in b.f]
    return b


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output-dir',type=Path,default=ROOT)
    args=ap.parse_args()
    original=Path(base.__file__).read_bytes()
    assert hashlib.sha256(original).hexdigest()==BASE_SHA256, 'Base generator changed'
    out=args.output_dir.resolve()
    (out/'assets').mkdir(parents=True,exist_ok=True)
    path=out/'assets'/'infected_warehouse_damaged.glb'
    meshes=[damaged_shell(),damaged_mantle()]
    stats=base.export(path,meshes)
    assert list(stats)==['WarehouseShell','Infection']
    assert sum(m['triangles'] for m in stats.values())<6000
    assert max(m['horizontal_radius'] for m in stats.values())<=4.5
    checks={}
    for m in meshes:
        v,n,c,uv,mask,f=m.arrays()
        area=np.linalg.norm(np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]]),axis=1)*.5
        assert all(np.isfinite(a).all() for a in [v,n,c,uv,mask])
        assert (c[:,3]==1).all()
        checks[m.name]={'zero_area_triangles':int((area<1e-8).sum()),
                        'interior_mask_vertices':int((mask[:,0]>0).sum()),
                        'normalized_normals':bool(np.allclose(np.linalg.norm(n,axis=1),1,atol=1e-5))}
    metadata={
        'state':'damaged_alive', 'recommended_health_ratio_range':'0 < hp/max_hp <= 0.5',
        'meshes':stats, 'total_triangles':sum(m['triangles'] for m in stats.values()),
        'glb_bytes':path.stat().st_size,
        'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'base_generator_sha256':BASE_SHA256,
        'coordinate_system':'glTF +Y up, metres; ground origin unchanged',
        'surface_contract':{'names':['WarehouseShell','Infection'],
                            'opaque_mesh_surfaces':2,'alpha_mode':'OPAQUE',
                            'attributes':['POSITION','NORMAL','COLOR_0','TEXCOORD_0','TEXCOORD_1'],
                            'colors':'Original linear RGB palette and alpha=1',
                            'uv0':'Original fibre texture convention',
                            'uv1':'Interior alarm mask in x, y=0'},
        'authored_changes':[
            '62% of the high roof length removed; foreground corrugated slab folds down by 1.78 m',
            'Front/left masonry bay reduced to jagged 0.6-1.5 m wall; large in-footprint rubble',
            'Rear wall central breach lowers roughly 2 m; two tall piers retain warehouse identity',
            '97.5 degree camera-facing crown sector excised above 2.58 m, with opaque torn edges and exposed cavity',
            'Live column, roots, entrances, ground slab, surviving crown and material masks retained'],
        'validation':checks,
        'limits':'Geometry/data validation only; parent must check Godot import, material assignment and ordinary-camera visibility.'}
    (out/'geometry_metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps(metadata,indent=2))


if __name__=='__main__':
    main()
