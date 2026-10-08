"""Offline support/transfer correction for the original infected rig.

Only the walk is changed. Distances are meters in original armature space
(forward -Y). Runtime travels Godot -Z at 1.12 meters per normalized cycle.
During stance every point of the rigid shoe moves +Y at exactly that rate.
The generator bakes these poses; no constraint, IK, or skeleton runs in game.
"""
import math

import bpy
from mathutils import Matrix, Vector

STRIDE = 1.12
LEFT_STANCE = 7.0 / 12.0
RIGHT_LAND = 6.0 / 12.0
RIGHT_STANCE = 6.0 / 12.0


def trajectory(phase, land, duration, center, clearance, droop):
    """Long linear support followed by eased, low unequal recovery.

    Recovery's endpoint tangents match stance, avoiding a positional or
    velocity discontinuity in the editable continuous trajectory. The
    shipped 12-frame linear interpolation is measured separately.
    """
    q = (phase - land) % 1.0
    front = center - STRIDE * duration * 0.5
    rear = center + STRIDE * duration * 0.5
    if q <= duration:
        return front + STRIDE * q, 0.0, 0.0, True
    u = (q - duration) / (1.0 - duration)
    u2, u3 = u*u, u*u*u
    tangent = STRIDE * (1.0 - duration)
    y = (2*u3 - 3*u2 + 1)*rear + (u3 - 2*u2 + u)*tangent
    y += (-2*u3 + 3*u2)*front + (u3 - u2)*tangent
    arch = math.sin(math.pi * u) ** 2
    return y, clearance * arch, droop * arch, False


class SupportGait:
    def __init__(self, rig, mesh, legacy_pose):
        self.rig, self.mesh, self.legacy_pose = rig, mesh, legacy_pose
        self.shoes = {}
        for side in ('L', 'R'):
            index = mesh.vertex_groups['foot.' + side].index
            ankle = rig.data.bones['foot.' + side].head_local
            self.shoes[side] = [v.co.copy() - ankle for v in mesh.data.vertices
                                if any(g.group == index and g.weight > .99 for g in v.groups)]
        self.diagnostics = []

    def place_bone(self, name, head, tail):
        rest = self.rig.data.bones[name]
        rotation = (rest.tail_local-rest.head_local).rotation_difference(tail-head)
        rotation = rotation @ rest.matrix_local.to_quaternion()
        self.rig.pose.bones[name].matrix = Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
        bpy.context.view_layer.update()

    def place_leg(self, side, ankle, shoe_rotation):
        thigh = self.rig.pose.bones['thigh.' + side]
        hip = thigh.head.copy()
        upper = self.rig.data.bones['thigh.' + side].length
        lower = self.rig.data.bones['shin.' + side].length
        line = ankle - hip
        reach = line.length
        assert abs(upper-lower) + 1e-5 < reach < upper+lower - 1e-5, (side, reach, upper+lower)
        direction = line.normalized()
        along = (upper*upper - lower*lower + reach*reach) / (2*reach)
        bend = math.sqrt(max(0.0, upper*upper - along*along))
        # A slightly outward, forward knee keeps the damaged shuffling stance.
        pole = Vector((.055 if side == 'L' else -.085, -1.0, 0.0))
        knee_direction = (pole-direction*direction.dot(pole)).normalized()
        knee = hip + direction*along + knee_direction*bend
        self.place_bone('thigh.' + side, hip, knee)
        self.place_bone('shin.' + side, knee, ankle)
        rest = self.rig.data.bones['foot.' + side]
        rotation = shoe_rotation @ rest.matrix_local.to_3x3()
        self.rig.pose.bones['foot.' + side].matrix = Matrix.Translation(ankle) @ rotation.to_4x4()
        bpy.context.view_layer.update()
        error = (self.rig.pose.bones['foot.' + side].head - ankle).length
        assert error < 2e-6, (side, error)
        return {'reach_m': reach, 'maximum_reach_m': upper+lower, 'knee_bend_offset_m': bend, 'ankle_error_m': error}

    def pose(self, t, clip):
        # Pose-matrix assignment decomposes to float rotation/scale channels.
        # Clear that roundoff before the legacy function (which resets only
        # location/rotation) so walk authoring cannot leak into other clips.
        for bone in self.rig.pose.bones:
            bone.scale = (1, 1, 1)
        self.legacy_pose(t, clip)
        if clip != 'walk':
            return
        phase = t % 1.0
        # Retain legacy spine, shoulders, head and arm imbalance. Lower the
        # pelvis 9 cm to permit bent-knee load transfer at the existing stride.
        # Override legacy floor compensation before solving grounded ankles.
        self.rig.pose.bones['root'].location = (0, 0, 0)
        self.rig.pose.bones['hips'].location = (0, -.09 + .012*math.sin(phase*math.tau), 0)
        bpy.context.view_layer.update()
        row = {'phase': phase, 'feet': {}}
        for side, args in (
            ('L', (0.0, LEFT_STANCE, .015, .090, -.060)),
            ('R', (RIGHT_LAND, RIGHT_STANCE, .035, .028, .100)),
        ):
            y, lift, pitch, support = trajectory(phase, *args)
            rotation = Matrix.Rotation(pitch, 3, 'X')
            sole_offset = min((rotation @ v).z for v in self.shoes[side])
            ankle = Vector((.14 if side == 'L' else -.14, y, lift-sole_offset))
            row['feet'][side] = dict(self.place_leg(side, ankle, rotation),
                                      ankle_target=list(ankle), clearance_m=lift,
                                      shoe_pitch_rad=pitch, authored_stance=support)
        self.diagnostics.append(row)
