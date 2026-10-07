extends RefCounted
## Visual sockets only. Never use these coordinates for range, supply, or hit tests.
## Human barrels are part of ArmR. Siege-cart coordinates are authored GLB space.
const ActorVisuals = preload("res://actor_visuals.gd")
const SIEGE_MUZZLE := Vector3(0, 2.116018, -1.205950)
const MORTAR_MUZZLE := Vector3(0, 2.21, -2.40)

static func anchor(source: Dictionary) -> Dictionary:
	var kind: String = str(source.get("kind", ""))
	var node: Variant = source.get("node")
	if kind not in ["guard", "grenade", "siegecart", "tower", "mortar"] or not is_instance_valid(node) or not node is Node3D:
		return {}
	var result: Dictionary = {"node": node, "kind": kind}
	if kind == "tower":
		# Twin front rings in build_defenses.py; exported (x,z,-y), no model pivot offset.
		result.barrel = int(source.get("shots", 0)) % 2
		result.local = Vector3(-.22 if result.barrel == 0 else .22, 3.30, -1.23)
	return result

static func world_position(socket: Dictionary, rendered: Dictionary, fallback: Vector3) -> Vector3:
	var node: Variant = socket.get("node")
	if not is_instance_valid(node) or not node is Node3D:
		return fallback
	var state: Dictionary = rendered.get(node.get_instance_id(), {})
	var world: Transform3D = state.get("world", node.global_transform)
	var kind: String = str(socket.get("kind", ""))
	if kind == "siegecart":
		return world * SIEGE_MUZZLE
	if kind == "tower":
		return world * socket.local
	if kind == "mortar":
		# structure_visuals.gd::_artillery front barrel cap, in building-root space.
		return world * MORTAR_MUZZLE
	if kind not in ["guard", "grenade"]:
		return fallback
	var local: Vector3 = ActorVisuals.muzzle_local(kind)
	var parts: Array = state.get("parts", [])
	var part_index: int = ActorVisuals.muzzle_part_index(kind)
	if parts.size() == ActorVisuals.parts_for(kind).size():
		# Exactly the same root/part composition as HordeRenderer.update_friends.
		return world * parts[part_index] * local
	var skeleton: Node3D = node.get_meta(&"actor_visuals", null)
	if not is_instance_valid(skeleton):
		return fallback
	var nodes: Array[Node3D] = ActorVisuals.part_nodes(skeleton)
	if part_index >= nodes.size(): return fallback
	var arm: Node3D = nodes[part_index]
	var root_local: Transform3D = node.global_transform.affine_inverse() * arm.global_transform
	return world * root_local * local
