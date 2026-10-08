"""Check source GLBs without invoking Blender/Godot or modifying the assets."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def read_glb(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", raw)
    assert (magic, version, length) == (b"glTF", 2, len(raw))
    offset = 12
    chunks = {}
    while offset < length:
        size, kind = struct.unpack_from("<II", raw, offset)
        chunks[kind] = raw[offset + 8:offset + 8 + size]
        offset += 8 + size
    return json.loads(chunks[0x4e4f534a]), chunks[0x004e4942]


def accessor(gltf, binary, index):
    item = gltf["accessors"][index]
    view = gltf["bufferViews"][item["bufferView"]]
    assert "sparse" not in item
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[item["type"]]
    fmt = "<" + {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[item["componentType"]] * width
    stride = view.get("byteStride", struct.calcsize(fmt))
    offset = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    return [struct.unpack_from(fmt, binary, offset + i * stride) for i in range(item["count"])]


def main():
    manifest = json.loads((ROOT / "infected_manifest.json").read_text())
    report = {"passed": True, "lods": {}}
    expected_names = [name for clip in manifest["clips"].values() for name in clip["poses"]]
    for label, lod in manifest["lods"].items():
        path = ROOT / lod["file"]
        gltf, binary = read_glb(path)
        assert not gltf.get("skins") and not gltf.get("animations")
        assert not gltf.get("extensionsRequired")
        assert len(gltf["materials"]) == 1
        assert len(gltf["meshes"]) == len(gltf["nodes"]) == 32
        assert sorted(node["name"] for node in gltf["nodes"]) == sorted(expected_names)
        reference_uv = reference_triangles = None
        min_y = math.inf
        max_y = -math.inf
        for node in gltf["nodes"]:
            assert node.get("translation", [0, 0, 0]) == [0, 0, 0]
            assert node.get("rotation", [0, 0, 0, 1]) == [0, 0, 0, 1]
            assert node.get("scale", [1, 1, 1]) == [1, 1, 1]
            assert "matrix" not in node and "skin" not in node
            primitives = gltf["meshes"][node["mesh"]]["primitives"]
            assert len(primitives) == 1
            primitive = primitives[0]
            assert primitive.get("mode", 4) == 4
            attrs = {key: accessor(gltf, binary, value) for key, value in primitive["attributes"].items()}
            assert set(attrs) == {"POSITION", "NORMAL", "TEXCOORD_0", "TEXCOORD_1"}
            count = len(attrs["POSITION"])
            assert count == lod["expected_imported_vertices_per_pose"]
            assert all(len(values) == count for values in attrs.values())
            side = math.ceil(math.sqrt(count))
            ids = [math.floor(v * side) * side + math.floor(u * side) for u, v in attrs["TEXCOORD_1"]]
            assert sorted(ids) == list(range(count)), (label, node["name"], "corner ID bijection")
            uv_by_id = {i: uv for i, uv in zip(ids, attrs["TEXCOORD_0"])}
            indices = [value[0] for value in accessor(gltf, binary, primitive["indices"])]
            assert len(indices) == 3 * lod["triangles_per_pose"]
            assert all(0 <= index < count for index in indices)
            triangles = sorted(tuple(ids[index] for index in indices[offset:offset + 3]) for offset in range(0, len(indices), 3))
            if reference_uv is None:
                reference_uv, reference_triangles = uv_by_id, triangles
            else:
                assert uv_by_id == reference_uv, (label, node["name"], "original atlas UVs")
                assert triangles == reference_triangles, (label, node["name"], "fixed corner topology")
            for key, values in attrs.items():
                assert all(math.isfinite(value) for row in values for value in row), (node["name"], key)
            assert all(0.99 < sum(n * n for n in normal) < 1.01 for normal in attrs["NORMAL"])
            heights = [position[1] for position in attrs["POSITION"]]
            assert min(heights) >= -1e-6
            min_y = min(min_y, min(heights))
            max_y = max(max_y, max(heights))
        image = gltf["images"][0]
        view = gltf["bufferViews"][image["bufferView"]]
        offset = view.get("byteOffset", 0)
        embedded_atlas = binary[offset:offset + view["byteLength"]]
        assert hashlib.sha256(embedded_atlas).hexdigest() == manifest["atlas_sha256"]
        report["lods"][label] = {"poses": 32, "triangles_per_pose": lod["triangles_per_pose"], "vertices_per_pose": count, "uv2_grid_side": side, "all_corner_ids_unique_complete_and_stable": True, "atlas_uv_and_embedded_image_preserved": True, "fixed_topology": True, "no_skeleton_or_animation": True, "all_node_transforms_identity": True, "floor_safe_endpoints_and_linear_blends": True, "min_y_m": min_y, "max_y_m": max_y, "bytes": len(path.read_bytes()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    (ROOT / "validation/glb_contract_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
