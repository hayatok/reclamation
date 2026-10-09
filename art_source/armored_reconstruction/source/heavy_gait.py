"""Original weighted industrial-worker movement, baked offline only.

Blender armature space is -Y forward / +Z up. Runtime uses measured planar
travel divided by STRIDE; wall-clock time never drives a moving foot.
"""
import math
import bpy
from mathutils import Matrix, Vector

STRIDE = 1.20
SPEED = 1.20
STANCE = .625


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x*x*(3.0-2.0*x)


def foot_path(phase, side):
    q = (phase-(0.0 if side == 'L' else .5)) % 1.0
    front = -.36
    if q <= STANCE:
        y = front + STRIDE*q
        lift = 0.0
        pitch = .22*smooth((q-.48)/(STANCE-.48))
        support = True
    else:
        u = (q-STANCE)/(1-STANCE)
        # Heavy boots clear rubble with a short bent-knee recovery; the burdened
        # left side lifts less and catches up late, without changing foot speed.
        knots = [(0., front+STRIDE*STANCE, 0.), (.30, .24, .095 if side=='L' else .13),
                 (.65, -.18, .125 if side=='L' else .17), (1., front, 0.)]
        for (a, ay, az), (b, by, bz) in zip(knots, knots[1:]):
            if a <= u <= b:
                k=smooth((u-a)/(b-a))
                y,lift=ay+(by-ay)*k,az+(bz-az)*k
                break
        pitch=.22*(1-smooth(u/.35))-.12*math.sin(math.pi*u)**2
        support=False
    return q,y,lift,pitch,support


class HeavyGait:
    def __init__(self, rig, mesh):
        self.rig,self.mesh=rig,mesh
        self.shoes={}
        for side in ('L','R'):
            index=mesh.vertex_groups['foot.'+side].index
            ankle=rig.data.bones['foot.'+side].head_local
            self.shoes[side]=[v.co.copy()-ankle for v in mesh.data.vertices
              if any(g.group==index and g.weight>.99 for g in v.groups)]
        self.diagnostics=[]

    def place(self,name,head,tail):
        head,tail=Vector(head),Vector(tail)
        rest=self.rig.data.bones[name]
        rotation=(rest.tail_local-rest.head_local).rotation_difference(tail-head)
        rotation=rotation @ rest.matrix_local.to_quaternion()
        self.rig.pose.bones[name].matrix=Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
        bpy.context.view_layer.update()

    def aim(self,name,direction):
        bone=self.rig.pose.bones[name]
        self.place(name,bone.head.copy(),bone.head+Vector(direction).normalized()*self.rig.data.bones[name].length)

    def solve(self,upper_name,lower_name,target,pole):
        start=self.rig.pose.bones[upper_name].head.copy()
        upper=self.rig.data.bones[upper_name].length
        lower=self.rig.data.bones[lower_name].length
        line=target-start
        reach=line.length
        assert abs(upper-lower)+1e-5 < reach < upper+lower-1e-5, (upper_name,reach,upper+lower)
        direction=line.normalized()
        along=(upper*upper-lower*lower+reach*reach)/(2*reach)
        bend=math.sqrt(max(0.0,upper*upper-along*along))
        pole=Vector(pole)
        knee_direction=(pole-direction*direction.dot(pole)).normalized()
        joint=start+direction*along+knee_direction*bend
        self.place(upper_name,start,joint)
        self.place(lower_name,joint,target)
        return dict(reach_m=reach,maximum_reach_m=upper+lower,joint_bend_offset_m=bend)

    def shoe(self,side,y,lift,pitch,support):
        rotation=Matrix.Rotation(pitch,3,'X')
        points=self.shoes[side]
        low=min(v.z for v in points)
        toe=min((v for v in points if v.z<low+.024),key=lambda v:v.y)
        rotated_toe=rotation @ toe
        sole=min((rotation @ v).z for v in points)
        ankle=Vector((.17 if side=='L' else -.17,y+toe.y-rotated_toe.y,lift-sole))
        diagnostics=self.solve('thigh.'+side,'shin.'+side,ankle,
          (.04 if side=='L' else -.04,-1.,.0))
        rest=self.rig.data.bones['foot.'+side]
        self.rig.pose.bones['foot.'+side].matrix=Matrix.Translation(ankle) @ (rotation @ rest.matrix_local.to_3x3()).to_4x4()
        bpy.context.view_layer.update()
        diagnostics.update(ankle_target=list(ankle),clearance_m=lift,shoe_pitch_rad=pitch,
          authored_stance=support,toe_target=list(ankle+rotated_toe))
        return diagnostics

    def pose(self,phase,clip):
        for bone in self.rig.pose.bones:
            bone.rotation_euler=(0,0,0)
            bone.location=(0,0,0)
            bone.scale=(1,1,1)
        bpy.context.view_layer.update()
        phase=phase%1.0 if clip in ('idle','walk') else min(max(phase,0.),1.)
        a=phase*math.tau
        walking=clip=='walk'
        sway=math.sin(a) if walking else .10*math.sin(a)
        bob=.007*(1-math.cos(2*a)) if walking else .004*math.sin(a)
        # A low center of mass and restrained shoulder roll carry the vest's
        # weight. Wide hips and a blunt chest are different from runner anatomy.
        self.place('hips',(.019*sway,.015,.785+bob),(.019*sway,.015,.905+bob))
        self.aim('spine',(-.014*sway,-.070,.255))
        self.aim('chest',(.02,-.065,.130))
        self.aim('neck',(-.025,-.046,.052))
        self.aim('head',(.013,-.025,.150))
        row={'phase':phase,'clip':clip,'feet':{}}
        for side,sign in [('L',1),('R',-1)]:
            if walking:
                _,y,lift,pitch,support=foot_path(phase,side)
            else:
                y,lift,pitch,support=(-.10 if side=='L' else .15),0.,0.,True
            row['feet'][side]=self.shoe(side,y,lift,pitch,support)
            drive=sway*sign
            # Left shoulder is burdened; right exposed hand probes ahead. A
            # visible elbow fold prevents the old rigid-pendulum silhouette.
            self.aim('upper_arm.'+side,(sign*.10,-.065-(drive*.06 if walking else 0.),-.27))
            self.aim('forearm.'+side,(sign*.012,-.18 if side=='R' else -.09-drive*.035,-.205))
            self.aim('hand.'+side,(sign*.009,-.07,-.105))
        if clip=='attack':
            # Gameplay already applies damage immediately. Start on the heavy
            # down-and-forward contact pose, settle, draw back, then grab-ready.
            recoil=smooth((phase-.12)/.48)
            ready=smooth((phase-.70)/.30)
            self.aim('spine',(.015,-.17+.10*recoil,.20+.055*recoil))
            self.aim('chest',(.025,-.11+.045*recoil,.09+.04*recoil))
            for side,sign in [('L',1),('R',-1)]:
                self.aim('upper_arm.'+side,(sign*.14,-.29+.19*recoil-.04*ready,-.15-.10*recoil))
                self.aim('forearm.'+side,(sign*.015,-.31+.15*recoil-.035*ready,-.15-.04*recoil))
                self.aim('hand.'+side,(sign*.008,-.105+.035*recoil,-.08))
            self.aim('head',(.025,-.085+.060*recoil,.13))
        elif clip=='death':
            t=smooth(phase)
            settle=smooth((phase-.28)/.72)
            buckle=math.sin(math.pi*phase)**2
            # First buckle, then release support and unfold into broad prone
            # contact. Arms must not prop the pelvis above the settled body.
            self.aim('spine',(.015*(1-settle),-.07*(1-settle)-.09*buckle,.255))
            self.aim('chest',(.02*(1-settle),-.065*(1-settle),.130))
            self.aim('neck',(-.025*(1-settle),-.046*(1-settle),.052))
            self.aim('head',(.013*(1-settle),-.025*(1-settle),.150))
            for side,sign in [('L',1),('R',-1)]:
                self.aim('upper_arm.'+side,(sign*(.10+.025*settle),-.065*(1-settle),-.27))
                self.aim('forearm.'+side,(sign*.012,(-.18 if side=='R' else -.09)*(1-settle),-.225))
                self.aim('hand.'+side,(sign*.009,-.07*(1-settle),-.12))
                # Releasing the planted legs makes the body settle as a whole,
                # while preserving every authored segment's physical length.
                thigh=self.rig.pose.bones['thigh.'+side]
                thigh_direction=(thigh.tail-thigh.head).normalized().lerp(Vector((sign*.015,0.,-1.)).normalized(),settle)
                self.aim('thigh.'+side,thigh_direction)
                shin=self.rig.pose.bones['shin.'+side]
                shin_direction=(shin.tail-shin.head).normalized().lerp(Vector((0.,0.,-1.)),settle)
                self.aim('shin.'+side,shin_direction)
                self.aim('foot.'+side,(sign*.14*settle,-.188+.038*settle,-.045-.025*settle))
            # Root has orientation only: CorpseMotion exclusively owns world
            # trajectory. The final plane is prone, not a hands-and-feet fold.
            root=self.rig.pose.bones['root']
            root.rotation_euler=(t*math.pi/2,0.,-.035*math.sin(math.pi*phase))
            bpy.context.view_layer.update()
        if clip!='walk':
            evaluated=self.mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            low=min(v.co.z for v in evaluated.data.vertices)
            # Ground normalization is an offline pose-space floor offset only.
            # No forward, lateral or world root displacement is exported.
            self.rig.pose.bones['root'].location.y-=low
            bpy.context.view_layer.update()
        self.diagnostics.append(row)
