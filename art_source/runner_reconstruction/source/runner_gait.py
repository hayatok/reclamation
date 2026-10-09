"""Original offline runner posing. No rig, IK, physics, or clip clock in game.

Coordinates are Blender armature space: -Y forward and +Z up. A full
left/right cycle travels STRIDE meters. Runtime integrates measured root
travel, so the authored support feet oppose translation at the same rate.
"""
import math

import bpy
from mathutils import Matrix, Vector

STRIDE = 1.72
STANCE = 4.0 / 12.0


def smooth(u):
    return u * u * (3.0 - 2.0 * u)


def foot_path(phase, side):
    q = (phase - (0.0 if side == 'L' else 0.5)) % 1.0
    # The forefoot remains fixed in world travel during the support interval.
    front = -.27
    if q <= STANCE:
        y = front + STRIDE * q
        lift = 0.0
        pitch = .42 * smooth(max(0.0, (q - .19) / (STANCE - .19)))
        support = True
    else:
        u = (q - STANCE) / (1.0 - STANCE)
        # Delayed forward recovery keeps the heel close to the rump first.
        # The resulting bent recovery leg is deliberately visible at RTS size.
        knots = [(0.0, front+STRIDE*STANCE, 0.0), (.24, .37, .31),
                 (.50, -.01, .40 if side == 'L' else .35),
                 (.78, -.31, .18), (1.0, front, 0.0)]
        for (a, ay, az), (b, by, bz) in zip(knots, knots[1:]):
            if a <= u <= b:
                k = smooth((u-a)/(b-a))
                y, lift = ay+(by-ay)*k, az+(bz-az)*k
                break
        pitch = .42*(1-smooth(min(u/.25, 1.0))) - .16*math.sin(math.pi*u)**2
        support = False
    return q, y, lift, pitch, support


class RunnerGait:
    def __init__(self, rig, mesh):
        self.rig, self.mesh = rig, mesh
        self.shoes = {}
        for side in ('L', 'R'):
            index = mesh.vertex_groups['foot.' + side].index
            ankle = rig.data.bones['foot.' + side].head_local
            self.shoes[side] = [v.co.copy() - ankle for v in mesh.data.vertices
                                if any(g.group == index and g.weight > .99 for g in v.groups)]
        self.diagnostics = []

    def place(self, name, head, tail):
        head, tail = Vector(head), Vector(tail)
        rest = self.rig.data.bones[name]
        rotation = (rest.tail_local-rest.head_local).rotation_difference(tail-head)
        rotation = rotation @ rest.matrix_local.to_quaternion()
        self.rig.pose.bones[name].matrix = Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
        bpy.context.view_layer.update()

    def aim(self, name, direction):
        bone = self.rig.pose.bones[name]
        self.place(name, bone.head.copy(), bone.head + Vector(direction).normalized()*self.rig.data.bones[name].length)

    def solve(self, upper_name, lower_name, target, pole):
        start = self.rig.pose.bones[upper_name].head.copy()
        upper = self.rig.data.bones[upper_name].length
        lower = self.rig.data.bones[lower_name].length
        line = target-start
        reach = line.length
        assert abs(upper-lower)+1e-5 < reach < upper+lower-1e-5, (upper_name, reach, upper+lower)
        direction = line.normalized()
        along = (upper*upper-lower*lower+reach*reach)/(2*reach)
        bend = math.sqrt(max(0.0, upper*upper-along*along))
        pole = Vector(pole)
        knee_direction = (pole-direction*direction.dot(pole)).normalized()
        joint = start+direction*along+knee_direction*bend
        self.place(upper_name, start, joint)
        self.place(lower_name, joint, target)
        return dict(reach_m=reach, maximum_reach_m=upper+lower, joint_bend_offset_m=bend)

    def shoe(self, side, y, lift, pitch, support):
        # Rotate the shoe around its forward toe during late stance, allowing
        # ankle rise and push-off without pulling the contact toe through soil.
        rotation = Matrix.Rotation(pitch, 3, 'X')
        points = self.shoes[side]
        low = min(v.z for v in points)
        toe = min((v for v in points if v.z < low+.032), key=lambda v:v.y)
        rotated_toe = rotation @ toe
        sole = min((rotation @ v).z for v in points)
        ankle = Vector((.135 if side == 'L' else -.135,
                        y + toe.y-rotated_toe.y, lift-sole))
        diagnostics = self.solve('thigh.'+side, 'shin.'+side, ankle,
                                 (.07 if side == 'L' else -.06, -1.0, .0))
        rest = self.rig.data.bones['foot.'+side]
        self.rig.pose.bones['foot.'+side].matrix = Matrix.Translation(ankle) @ (rotation @ rest.matrix_local.to_3x3()).to_4x4()
        bpy.context.view_layer.update()
        diagnostics.update(ankle_target=list(ankle), clearance_m=lift, shoe_pitch_rad=pitch,
                           authored_stance=support, toe_target=list(ankle+rotated_toe))
        return diagnostics

    def pose(self, phase, clip):
        for bone in self.rig.pose.bones:
            bone.rotation_euler = (0, 0, 0)
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
        phase = phase % 1.0 if clip in ('idle', 'run') else min(max(phase,0.0),1.0)
        a = phase*math.tau
        running = clip == 'run'
        wave = math.sin(a) if running else .12*math.sin(a)
        # Deliberately low, forward chest and protruding head; this changes
        # articulated silhouette rather than applying a root lean to a doll.
        body_lift = .018*(1-math.cos(a*2)) if running else .004*math.sin(a)
        self.place('hips',(.014*wave, 0, .785+body_lift),(.014*wave,0,.905+body_lift))
        self.aim('spine',(.045*wave,-.20,.23))
        self.aim('chest',(-.025*wave,-.13,.08))
        self.aim('neck',(.012,-.08,.035))
        self.aim('head',(-.015,-.04,.15))
        row = {'phase':phase,'clip':clip,'feet':{}}
        for side, sign in [('L',1),('R',-1)]:
            if running:
                q,y,lift,pitch,support = foot_path(phase,side)
            else:
                y,lift,pitch,support = ((-.10 if side=='L' else .16),0.0,0.0,True)
            row['feet'][side] = self.shoe(side,y,lift,pitch,support)
            # Opposed arm drive with visibly flexed elbow. Right shoulder has
            # a damaged, low trailing hand; left hand is a forward hooked claw.
            shoulder = self.rig.pose.bones['upper_arm.'+side].head.copy()
            drive = wave*sign
            if running:
                elbow = shoulder+Vector((sign*.09,-drive*.19,.02-.18))
                wrist = shoulder+Vector((sign*.045,-.24-drive*.18,-.21+drive*.04))
                if side == 'R':
                    wrist.z -= .07
                    wrist.y += .05
            else:
                elbow = shoulder+Vector((sign*.07,-.03,-.26))
                wrist = shoulder+Vector((sign*.02,-.22,-.35))
            # Two segments aimed explicitly preserve unscaled arm lengths.
            self.aim('upper_arm.'+side,elbow-shoulder)
            elbow = self.rig.pose.bones['forearm.'+side].head.copy()
            self.aim('forearm.'+side,wrist-elbow)
            self.aim('hand.'+side,(sign*.008,-.08,-.12))
        if clip == 'attack':
            recover = smooth(phase)
            self.aim('spine',(.0,-.29+.09*recover,.15+.08*recover))
            for side, sign in [('L',1),('R',-1)]:
                self.aim('upper_arm.'+side,(sign*.10,-.38+.25*recover,-.03-.16*recover))
                self.aim('forearm.'+side,(sign*.01,-.26+.08*recover,-.02-.14*recover))
                self.aim('hand.'+side,(sign*.005,-.12,-.07))
        elif clip == 'death':
            # Root-local topple only; existing CorpseMotion retains trajectory.
            t = smooth(phase)
            root = self.rig.pose.bones['root']
            root.rotation_euler=(t*1.46,0,-t*.24)
            self.rig.pose.bones['head'].rotation_euler.x += t*.28
            bpy.context.view_layer.update()
        if clip != 'run':
            evaluated = self.mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            low=min(v.co.z for v in evaluated.data.vertices)
            self.rig.pose.bones['root'].location.y -= low
            bpy.context.view_layer.update()
        self.diagnostics.append(row)
