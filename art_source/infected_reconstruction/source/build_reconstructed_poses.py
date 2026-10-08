"""Reconstruct interpolation-compatible baked poses from the verified base rig.

This is a NEW reconstruction, not a recovered 039 generator or byte-identical
asset. Run with Blender 4.3.2:
  blender --background --factory-startup --python source/build_reconstructed_poses.py

The legacy file is preserved verbatim for provenance. Only its `pose` function
is compiled here; its top-level modeling/export/build operations never execute.
"""
import ast
import hashlib
import json
import math
import time
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "source"
ASSETS = ROOT / "assets"
CLIPS = {"idle": (1.6, 2), "walk": (1.2, 12), "attack": (0.8, 8), "death": (1.2, 10)}
FAR_RATIO = 0.16


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def freeze_triangles(obj):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Fixed rest-pose triangulation", "TRIANGULATE")
    # All topology-changing operations happen before skeletal deformation.
    if obj.modifiers.find(mod.name) > 0:
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    assert all(len(p.vertices) == 3 for p in obj.data.polygons)


def encode_corner_ids(obj):
    data = obj.data
    assert len(data.uv_layers) == 1, "Preserve the original single atlas UV layer."
    data.uv_layers[0].name = "UVMap"
    ids = data.uv_layers.new(name="CornerID")
    count = len(data.loops)
    side = math.ceil(math.sqrt(count))
    for corner in range(count):
        # Blender flips V when exporting glTF. Store the inverse here so Godot
        # receives the requested cell centers, including the final partial row.
        ids.data[corner].uv = ((corner % side + 0.5) / side, 1.0 - (corner // side + 0.5) / side)
    data.uv_layers.active_index = 0
    data.uv_layers[0].active_render = True
    return count, side


def topology_digest(data):
    indices = [data.loops[i].vertex_index for p in data.polygons for i in p.loop_indices]
    return hashlib.sha256(json.dumps(indices).encode()).hexdigest()


def pose_time(clip, frame, count):
    if clip == "idle":
        return frame * 0.5 + 0.25
    if clip == "walk":
        return frame / count
    if clip == "attack":
        # Retained renderer applies damage immediately: first pose is contact.
        # Reconstruct a contact-to-recovery clip from the legacy reach function.
        return 0.5 + 0.5 * frame / (count - 1)
    return frame / (count - 1)


def main():
    started = time.monotonic()
    original = SOURCE / "infected_civilian_original.blend"
    legacy = SOURCE / "legacy_build_infected.py"
    bpy.ops.wm.open_mainfile(filepath=str(original))
    rig = bpy.data.objects["Infected_Rig"]
    mesh = bpy.data.objects["Infected_Civilian_Skinned"]
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = None
    assert len(mesh.data.materials) == 1
    assert len(mesh.data.uv_layers) == 1
    for image in bpy.data.images:
        if image.name.startswith("infected_atlas"):
            image.filepath = str(ASSETS / "infected_atlas.png")
    # Reset all channels before simplifying the rest mesh.
    for bone in rig.pose.bones:
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    freeze_triangles(mesh)
    far = mesh.copy()
    far.data = mesh.data.copy()
    far.name = "Infected_Civilian_Far_Rest"
    bpy.context.collection.objects.link(far)
    # Copy preserves original vertex groups, atlas UVs, and material. Collapse
    # the REST mesh exactly once, then reattach the original skeletal modifier.
    for mod in list(far.modifiers):
        far.modifiers.remove(mod)
    bpy.context.view_layer.objects.active = far
    decimate = far.modifiers.new("Single rest-pose far decimation", "DECIMATE")
    decimate.ratio = FAR_RATIO
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    freeze_triangles(far)
    # Decimation can leave stale custom-data entries. Validate once in rest
    # space, before assigning IDs, so the exporter never changes pose topology.
    far_triangles_before_cleanup = len(far.data.polygons)
    far_rest_cleanup = far.data.validate(verbose=False)
    far_duplicate_triangles_removed = far_triangles_before_cleanup - len(far.data.polygons)
    arm = far.modifiers.new("Original rig deformation", "ARMATURE")
    arm.object = rig
    counts = {}
    for label, obj in [("near", mesh), ("far", far)]:
        corners, side = encode_corner_ids(obj)
        counts[label] = {
            "triangles_per_pose": len(obj.data.polygons),
            "rest_mesh_vertices": len(obj.data.vertices),
            "expected_imported_vertices_per_pose": corners,
            "uv2_grid_side": side,
            "topology_sha256": topology_digest(obj.data),
            "rest_mesh_validation_changed": bool(far_rest_cleanup) if label == "far" else False,
            "duplicate_triangles_removed_before_corner_ids": far_duplicate_triangles_removed if label == "far" else 0,
        }
    # Extract only the original pose function, with its original globals bound
    # to the verified rig/near mesh. No source modeling/export code is executed.
    tree = ast.parse(legacy.read_text())
    node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "pose")
    scope = {"bpy": bpy, "math": math, "Matrix": Matrix, "Vector": Vector, "rig": rig, "mesh": mesh}
    exec(compile(ast.Module(body=[node], type_ignores=[]), str(legacy), "exec"), scope)
    pose = scope["pose"]
    pose(0.25, "idle")
    far.hide_render = True
    far.hide_set(True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "infected_pose_source.blend"))
    far.hide_set(False)
    far.hide_render = False
    manifest = {
        "status": "new_reconstruction_not_recovered_039",
        "generator": "source/build_reconstructed_poses.py",
        "original_rig": "source/infected_civilian_original.blend",
        "original_generator": "source/legacy_build_infected.py",
        "original_rig_sha256": sha256(original),
        "original_generator_sha256": sha256(legacy),
        "atlas_sha256": sha256(ASSETS / "infected_atlas.png"),
        "blender_version": bpy.app.version_string,
        "forward": "Godot -Z",
        "units": "meters",
        "fps": 30,
        "pose_count": 32,
        "bones_in_editable_source_only": len(rig.data.bones),
        "runtime_bones": 0,
        "clips": {},
        "lods": counts,
        "changes_from_verified_base": [
            "Far LOD decimated once in the rest pose, before deformation.",
            "One unique triangle-corner ID in UV2; stable correspondence across all poses.",
            "Attack starts at original t=0.5 contact and recovers through original t=1.0.",
            "All exported object transforms are identity; geometry carries coordinate conversion.",
        ],
        "validation_limits": [
            "No original 039 generator or full asset bytes were recovered; no byte identity claimed.",
            "Legacy walk mechanics retained; 1.12 m runtime stride is not independently reauthored.",
            "Native visual and gameplay review belongs to the integrating parent task.",
        ],
    }
    for clip, (duration, count) in CLIPS.items():
        manifest["clips"][clip] = {
            "duration": duration,
            "loop": clip in ["idle", "walk"],
            "poses": [f"{clip}_{i:02}" for i in range(count)],
            "legacy_pose_times": [pose_time(clip, i, count) for i in range(count)],
        }
    for label, src in [("near", mesh), ("far", far)]:
        baked = []
        samples = []
        for clip, (duration, count) in CLIPS.items():
            for frame in range(count):
                name = f"{clip}_{frame:02}"
                t = pose_time(clip, frame, count)
                pose(t, clip)
                deps = bpy.context.evaluated_depsgraph_get()
                evaluated = src.evaluated_get(deps)
                data = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=deps)
                assert topology_digest(data) == counts[label]["topology_sha256"], name
                data.transform(src.matrix_world)
                lowest = min(v.co.z for v in data.vertices)
                data.transform(Matrix.Translation((0, 0, -lowest)))
                assert not data.validate(verbose=True), "Exporter would mutate " + name
                obj = bpy.data.objects.new(name, data)
                bpy.context.collection.objects.link(obj)
                assert obj.name == name, obj.name
                assert obj.matrix_world == Matrix.Identity(4)
                baked.append(obj)
                samples.append({
                    "name": name,
                    "legacy_t": t,
                    "triangle_count": len(data.polygons),
                    "corner_count": len(data.loops),
                    "floor_correction_m": -lowest,
                    "min_height_m": min(v.co.z for v in data.vertices),
                    "max_height_m": max(v.co.z for v in data.vertices),
                })
        bpy.ops.object.select_all(action="DESELECT")
        for obj in baked:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = baked[0]
        filename = "infected_baked_poses.glb" if label == "near" else "infected_baked_poses_far.glb"
        bpy.ops.export_scene.gltf(
            filepath=str(ASSETS / filename), export_format="GLB", use_selection=True,
            export_animations=False, export_skins=False, export_morph=False,
            export_texcoords=True, export_normals=True, export_tangents=False,
            export_yup=True, export_materials="EXPORT", export_image_format="AUTO",
            export_draco_mesh_compression_enable=False, export_cameras=False,
            export_lights=False, export_extras=False,
        )
        counts[label]["samples"] = samples
        counts[label]["file"] = "assets/" + filename
        counts[label]["sha256"] = sha256(ASSETS / filename)
        counts[label]["bytes"] = (ASSETS / filename).stat().st_size
        # Do not leave duplicate pose names for the following LOD export.
        for obj in baked:
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.meshes.remove(data)
    manifest["triangles_per_pose"] = counts["near"]["triangles_per_pose"]
    manifest["far_triangles_per_pose"] = [counts["far"]["triangles_per_pose"]] * 32
    manifest["elapsed_seconds"] = round(time.monotonic() - started, 3)
    manifest["generator_sha256"] = sha256(Path(__file__))
    (ROOT / "infected_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("INFECTED_RECONSTRUCTION_OK", json.dumps({"lods": {k: {a: v[a] for a in ["triangles_per_pose", "expected_imported_vertices_per_pose", "uv2_grid_side", "bytes"]} for k, v in counts.items()}, "elapsed_seconds": manifest["elapsed_seconds"]}))


if __name__ == "__main__":
    main()
