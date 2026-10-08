"""Read-only, shader-equivalent comparison of frozen and trial GLB bytes.

Run from any directory with Python and numpy. No Blender/Godot is needed.
Measures the same material corner's velocity under exact linear pose blending,
then adds unchanged root motion. The minimum-height shoe is a contact proxy,
not a force or center-of-mass simulation.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np

from validate_glb import accessor, read_glb

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline', required=True, type=Path, help='Path to the verified v0.40 game source checkout')
arguments = parser.parse_args()
BASE = arguments.baseline.resolve()
AUDIT = ROOT / 'validation'
STRIDE, SAMPLES = 1.12, 12000


def load(path):
    spec, binary = read_glb(path)
    result = {}
    for node in spec['nodes']:
        assert all(key not in node for key in ['matrix', 'translation', 'rotation', 'scale'])
        primitive = spec['meshes'][node['mesh']]['primitives'][0]
        attrs = {k: np.array(accessor(spec, binary, v)) for k, v in primitive['attributes'].items()}
        side = math.ceil(math.sqrt(len(attrs['POSITION'])))
        uv2 = attrs['TEXCOORD_1']
        ids = np.floor(uv2[:, 0]*side).astype(int) + np.floor(uv2[:, 1]*side).astype(int)*side
        assert sorted(ids.tolist()) == list(range(len(ids)))
        order = np.argsort(ids)
        indices = np.array(accessor(spec, binary, primitive['indices'])).ravel().astype(int)
        result[node['name']] = {k: v[order] for k, v in attrs.items()}
        result[node['name']]['TRIANGLES'] = sorted(tuple(row) for row in ids[indices].reshape(-1, 3).tolist())
    return result, spec, binary


def far_shoe_ids(poses, reference_centers):
    p = poses['walk_00']['POSITION']
    parent = list(range(len(p)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    def union(a, b):
        parent[find(a)] = find(b)
    welded = {}
    for i, point in enumerate(p):
        key = tuple(np.round(point, 6))
        if key in welded:
            union(i, welded[key])
        else:
            welded[key] = i
    for i in range(0, len(p), 3):
        union(i, i+1)
        union(i, i+2)
    components = {}
    for i in range(len(p)):
        components.setdefault(find(i), []).append(i)
    return {side: min(components.values(), key=lambda ids: np.linalg.norm(np.unique(p[ids], axis=0).mean(axis=0)-center))
            for side, center in reference_centers.items()}


def contact(poses, foot_ids):
    phase = (np.arange(SAMPLES)+.5) / SAMPLES
    frame = np.floor(phase*12).astype(int)
    blend = phase*12-frame
    measured = {}
    for side, ids in foot_ids.items():
        f = np.array([poses[f'walk_{i:02}']['POSITION'][ids] for i in range(12)])
        p = f[frame]*(1-blend[:, None, None]) + f[(frame+1) % 12]*blend[:, None, None]
        dp = (f[(frame+1) % 12]-f[frame])*12
        low = np.argmin(p[:, :, 1], axis=1)
        velocity = dp[np.arange(SAMPLES), low].copy()
        velocity[:, 2] -= STRIDE
        measured[side] = {'height': p[np.arange(SAMPLES), low, 1], 'v': velocity,
                          'centroid': p.mean(axis=1), 'ids': np.array(ids)[low]}
    def summary(side, mask):
        m = measured[side]
        v, height = m['v'][mask], m['height'][mask]
        if not len(v):
            return None
        root = float(mask.mean()*STRIDE)
        path = float(np.linalg.norm(v[:, [0, 2]], axis=1).sum()/SAMPLES)
        return {'phase_fraction': float(mask.mean()), 'root_travel_m': root,
                'material_forward_drift_m': float(-v[:, 2].sum()/SAMPLES),
                'material_horizontal_path_m': path, 'path_over_root_travel': path/root,
                'min_shoe_height_m': float(height.min()), 'max_shoe_height_m': float(height.max()),
                'max_material_speed_over_root': float(np.linalg.norm(v[:, [0, 2]], axis=1).max()/STRIDE)}
    results = {'left_old_problem_window_0125_0375': summary('L', (phase >= .125) & (phase < .375)),
               'left_old_ground_core_1_6_to_1_3': summary('L', (phase >= 1/6) & (phase < 1/3)),
               'left_authored_stance_0_to_7_12': summary('L', phase < 7/12),
               'right_authored_stance_1_2_to_1': summary('R', phase >= .5),
               'geometrically_lower_shoe': {}, 'lower_or_tied_within_1_micron': {}, 'height_thresholds': {},
               'pose_segments': []}
    for side, other in [('L', 'R'), ('R', 'L')]:
        # Preserve the baseline's strict lower-shoe proxy. Also report its
        # near-tie ambiguity separately when both authored soles are grounded.
        results['geometrically_lower_shoe'][side] = summary(side, measured[side]['height'] < measured[other]['height'])
        results['lower_or_tied_within_1_micron'][side] = summary(side, measured[side]['height'] <= measured[other]['height']+1e-6)
        for threshold in [.002, .005, .01, .02]:
            results['height_thresholds'].setdefault(str(threshold), {})[side] = summary(side, measured[side]['height'] <= threshold)
    results['whole_cycle_maximum_shoe_clearance_m'] = {s: float(m['height'].max()) for s, m in measured.items()}
    for i in range(12):
        results['pose_segments'].append({'phase_start': i/12, 'phase_end': (i+1)/12,
                                       **{s: summary(s, frame == i) for s in foot_ids}})
    return results


def image_hash(spec, binary):
    image = spec['images'][0]
    view = spec['bufferViews'][image['bufferView']]
    start = view.get('byteOffset', 0)
    return hashlib.sha256(binary[start:start+view['byteLength']]).hexdigest()


def main():
    authored = json.loads((AUDIT / 'authored_foot_samples.json').read_text())
    report = {'passed': True, 'unchanged_runtime_stride_m': STRIDE,
              'interpolation_samples_per_cycle': SAMPLES,
              'method': __doc__, 'lods': {},
              'limits': ['Straight travel at unit actor scale only; turning may scrub feet.',
                         'Lowest-shoe/contact thresholds are geometric proxies, not force measurements.',
                         'Transfer and low recovery intentionally retain some near-ground slip.',
                         'No gameplay or subjective motion-quality verdict is supplied by these numbers.']}
    for lod, filename in [('near', 'infected_baked_poses.glb'), ('far', 'infected_baked_poses_far.glb')]:
        before_path, after_path = BASE / 'assets/models' / filename, ROOT / 'assets' / filename
        before, bs, bb = load(before_path)
        after, spec, binary = load(after_path)
        assert before.keys() == after.keys() and len(after) == 32
        max_nonwalk = {k: 0.0 for k in ['POSITION', 'NORMAL', 'TEXCOORD_0', 'TEXCOORD_1']}
        nonwalk_exact = True
        for name in before:
            assert before[name]['TRIANGLES'] == after[name]['TRIANGLES'], (lod, name, 'topology')
            for uv in ['TEXCOORD_0', 'TEXCOORD_1']:
                assert np.array_equal(before[name][uv], after[name][uv]), (lod, name, uv)
            if not name.startswith('walk_'):
                for attr in max_nonwalk:
                    error = float(np.abs(before[name][attr]-after[name][attr]).max())
                    max_nonwalk[attr] = max(max_nonwalk[attr], error)
                    nonwalk_exact &= np.array_equal(before[name][attr], after[name][attr])
        assert max_nonwalk['POSITION'] <= 1e-6, (lod, max_nonwalk)
        assert bs['materials'] == spec['materials']
        assert image_hash(bs, bb) == image_hash(spec, binary)
        foot_ids = authored['foot_corner_ids'] if lod == 'near' else far_shoe_ids(before, {
            s: np.array(authored['baked_samples'][0]['feet'][s]['centroid']) for s in ['L', 'R']})
        report['lods'][lod] = {'before_sha256': hashlib.sha256(before_path.read_bytes()).hexdigest(),
                               'after_sha256': hashlib.sha256(after_path.read_bytes()).hexdigest(),
                               'pose_count': len(after), 'nonwalk_pose_count': 20,
                               'nonwalk_attributes_bitwise_equal': bool(nonwalk_exact),
                               'nonwalk_max_absolute_attribute_error': max_nonwalk,
                               'all_pose_topology_and_uvs_exactly_unchanged': True,
                               'material_and_atlas_exactly_unchanged': True,
                               'foot_corner_counts': {s: len(ids) for s, ids in foot_ids.items()},
                               'before': contact(before, foot_ids), 'after': contact(after, foot_ids)}
        new_contact = report['lods'][lod]['after']
        assert new_contact['left_old_problem_window_0125_0375']['material_horizontal_path_m'] < .001
        assert new_contact['left_authored_stance_0_to_7_12']['material_horizontal_path_m'] < .001
        assert new_contact['right_authored_stance_1_2_to_1']['material_horizontal_path_m'] < .001
    (ROOT / 'validation/support_gait_comparison.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({lod: {key: item[key] for key in ['nonwalk_attributes_bitwise_equal', 'nonwalk_max_absolute_attribute_error']}
                      | {'before_left_window': item['before']['left_old_problem_window_0125_0375'],
                         'after_left_window': item['after']['left_old_problem_window_0125_0375'],
                         'left_stance': item['after']['left_authored_stance_0_to_7_12'],
                         'right_stance': item['after']['right_authored_stance_1_2_to_1']}
                      for lod, item in report['lods'].items()}, indent=2))


if __name__ == '__main__':
    main()
