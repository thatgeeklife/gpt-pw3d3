extends RefCounted

const MAX_LABELS := 256
const LABEL_HEIGHT_OFFSET := 0.012
const LABEL_RADIUS_MULTIPLIER := 1.8
const LABEL_MIN_FORWARD_DOT := -0.12
const LABEL_CLOSE_BUFFER_RADIUS := 4.0

var level_root: Node3D = null
var label_nodes: Array = []

func configure(new_level_root: Node3D) -> void:
	clear()
	level_root = new_level_root
	_ensure_pool()

func clear() -> void:
	for label_node in label_nodes:
		if label_node != null and is_instance_valid(label_node):
			label_node.queue_free()
	label_nodes.clear()
	level_root = null

func clear_assignments() -> void:
	for label_node in label_nodes:
		if label_node != null and is_instance_valid(label_node):
			label_node.visible = false

func update_labels(
	runtime_data: Resource,
	active_chunk_indices: Array[int],
	target_tile_index: int,
	player_global_position: Vector3,
	player_forward: Vector3,
	radius: float
) -> void:
	if runtime_data == null:
		clear_assignments()
		return
	if level_root == null or not is_instance_valid(level_root):
		clear_assignments()
		return

	_ensure_pool()

	var effective_radius: float = radius * LABEL_RADIUS_MULTIPLIER
	var radius_sq: float = effective_radius * effective_radius
	var close_buffer_sq: float = LABEL_CLOSE_BUFFER_RADIUS * LABEL_CLOSE_BUFFER_RADIUS
	var candidate_tiles: Array = []
	var seen: Dictionary = {}
	var flat_forward: Vector3 = Vector3(player_forward.x, 0.0, player_forward.z)
	if flat_forward.length_squared() > 0.0001:
		flat_forward = flat_forward.normalized()
	else:
		flat_forward = Vector3.FORWARD

	if runtime_data.is_valid_tile_index(target_tile_index):
		if not runtime_data.is_tile_completed_by_index(target_tile_index):
			var target_global_pos: Vector3 = level_root.to_global(runtime_data.get_tile_local_position(target_tile_index))
			var target_dist_sq: float = target_global_pos.distance_squared_to(player_global_position)
			candidate_tiles.append({"tile_index": target_tile_index, "dist_sq": target_dist_sq, "priority": 0})
			seen[target_tile_index] = true

	for chunk_index in active_chunk_indices:
		for tile_index_variant in runtime_data.get_chunk_tile_indices(chunk_index):
			var tile_index: int = int(tile_index_variant)
			_collect_candidate(
				runtime_data,
				tile_index,
				player_global_position,
				flat_forward,
				radius_sq,
				close_buffer_sq,
				candidate_tiles,
				seen
			)

	candidate_tiles.sort_custom(func(a, b):
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) < int(b["priority"])
		return float(a["dist_sq"]) < float(b["dist_sq"])
	)

	for label_index in range(label_nodes.size()):
		var label_node: Label3D = label_nodes[label_index]
		if label_node == null or not is_instance_valid(label_node):
			continue

		if label_index >= candidate_tiles.size() or label_index >= MAX_LABELS:
			label_node.visible = false
			continue

		var tile_index: int = int(candidate_tiles[label_index]["tile_index"])
		var local_pos: Vector3 = runtime_data.get_tile_local_position(tile_index)

		label_node.text = runtime_data.get_tile_color_code(tile_index)
		label_node.position = local_pos + Vector3(0.0, LABEL_HEIGHT_OFFSET, 0.0)
		label_node.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label_node.visible = true

func _collect_candidate(
	runtime_data: Resource,
	tile_index: int,
	player_global_position: Vector3,
	player_forward: Vector3,
	radius_sq: float,
	close_buffer_sq: float,
	candidate_tiles: Array,
	seen: Dictionary
) -> void:
	if seen.has(tile_index):
		return
	if runtime_data.is_tile_completed_by_index(tile_index):
		return

	var tile_global_pos: Vector3 = level_root.to_global(runtime_data.get_tile_local_position(tile_index))
	var to_tile: Vector3 = tile_global_pos - player_global_position
	to_tile.y = 0.0

	var dist_sq: float = to_tile.length_squared()
	if dist_sq > radius_sq:
		return
	if dist_sq <= 0.0001:
		return

	var forward_dot: float = to_tile.normalized().dot(player_forward)
	if dist_sq > close_buffer_sq and forward_dot < LABEL_MIN_FORWARD_DOT:
		return

	candidate_tiles.append({"tile_index": tile_index, "dist_sq": dist_sq, "priority": 1})
	seen[tile_index] = true

func _ensure_pool() -> void:
	if level_root == null or not is_instance_valid(level_root):
		return

	while label_nodes.size() < MAX_LABELS:
		var label_node := Label3D.new()
		label_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label_node.modulate = Color(0.16, 0.11, 0.07, 1.0)
		label_node.outline_modulate = Color(0.98, 0.95, 0.86, 1.0)
		label_node.outline_size = 2
		label_node.font_size = 56
		label_node.visible = false
		level_root.add_child(label_node)
		label_nodes.append(label_node)