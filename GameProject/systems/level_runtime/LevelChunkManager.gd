extends RefCounted

## Tracks active chunk visibility and dirty state for the current level runtime.

const LEVEL_CHUNK_STATE_SCRIPT := preload("res://systems/level_runtime/LevelChunkState.gd")
const ACTIVE_CHUNK_RADIUS := 1

var runtime_data: Resource = null
var chunk_states: Array = []
var active_chunk_lookup: Dictionary = {}

func clear() -> void:
	runtime_data = null
	chunk_states.clear()
	active_chunk_lookup.clear()

func initialize_from_runtime_data(new_runtime_data: Resource) -> void:
	clear()
	runtime_data = new_runtime_data
	if runtime_data == null:
		return

	for chunk_index in range(runtime_data.get_chunk_count()):
		var state = LEVEL_CHUNK_STATE_SCRIPT.new()
		state.configure(
			chunk_index,
			runtime_data.get_chunk_coord(chunk_index),
			runtime_data.get_chunk_tile_indices(chunk_index)
		)
		chunk_states.append(state)

func get_chunk_count() -> int:
	return chunk_states.size()

func get_chunk_state(chunk_index: int):
	if chunk_index < 0 or chunk_index >= chunk_states.size():
		return null
	return chunk_states[chunk_index]

func get_chunk_index_for_tile(tile_index: int) -> int:
	if runtime_data == null:
		return -1
	return runtime_data.get_chunk_index_for_tile(tile_index)

func get_active_chunk_indices() -> Array[int]:
	var indices: Array[int] = []
	for key in active_chunk_lookup.keys():
		indices.append(int(key))
	indices.sort()
	return indices

func is_chunk_active(chunk_index: int) -> bool:
	return active_chunk_lookup.has(chunk_index)

func set_active_chunks(active_indices: Array[int]) -> void:
	active_chunk_lookup.clear()
	for chunk_index in active_indices:
		active_chunk_lookup[int(chunk_index)] = true

func compute_active_chunk_indices_from_local_position(local_position: Vector3, radius: int = ACTIVE_CHUNK_RADIUS) -> Array[int]:
	var output: Array[int] = []
	if runtime_data == null:
		return output

	var center_chunk_index: int = runtime_data.get_chunk_index_from_local_position(local_position)
	if center_chunk_index == -1:
		return output

	var center_coord: Vector2i = runtime_data.get_chunk_coord(center_chunk_index)
	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var chunk_x: int = center_coord.x + offset_x
			var chunk_y: int = center_coord.y + offset_y
			var chunk_index: int = runtime_data.get_chunk_index_from_coords(chunk_x, chunk_y)
			if chunk_index == -1:
				continue
			output.append(chunk_index)

	output.sort()
	return output

func mark_chunk_dirty(chunk_index: int) -> void:
	var state = get_chunk_state(chunk_index)
	if state == null:
		return
	state.is_dirty = true

func mark_chunk_dirty_by_tile_index(tile_index: int) -> int:
	var chunk_index: int = get_chunk_index_for_tile(tile_index)
	if chunk_index == -1:
		return -1
	mark_chunk_dirty(chunk_index)
	return chunk_index

func mark_all_chunks_dirty() -> void:
	for state in chunk_states:
		state.is_dirty = true