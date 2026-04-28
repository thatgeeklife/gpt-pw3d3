extends Resource

## Active runtime representation of one generated level.
## Gameplay queries should use this data instead of tile scene nodes.

@export var level_id: String = ""
@export var level_name: String = ""
@export var theme_id: String = ""
@export var tile_count: int = 0
@export var bounds_min: Vector2i = Vector2i.ZERO
@export var bounds_max: Vector2i = Vector2i.ZERO
@export var border_tiles: int = 5
@export var room_width_cells: int = 0
@export var room_depth_cells: int = 0
@export var cell_size: float = 2.0
@export var tile_surface_y: float = 0.10
@export var chunk_size: int = 16
@export var chunk_count_x: int = 0
@export var chunk_count_y: int = 0

var tile_pixel_ids: PackedInt32Array = PackedInt32Array()
var tile_grid_x: PackedInt32Array = PackedInt32Array()
var tile_grid_y: PackedInt32Array = PackedInt32Array()
var tile_palette_indices: PackedInt32Array = PackedInt32Array()
var tile_completed: PackedByteArray = PackedByteArray()
var tile_local_x: PackedFloat32Array = PackedFloat32Array()
var tile_local_z: PackedFloat32Array = PackedFloat32Array()
var tile_chunk_indices: PackedInt32Array = PackedInt32Array()

var palette_colors: Array[Color] = []
var palette_codes: Array[String] = []
var palette_keys: Array[String] = []

var pixel_id_to_index: Dictionary = {}
var grid_key_to_index: Dictionary = {}
var chunk_tile_lists: Array = []
var chunk_coords: PackedVector2Array = PackedVector2Array()

func clear() -> void:
	level_id = ""
	level_name = ""
	theme_id = ""
	tile_count = 0
	bounds_min = Vector2i.ZERO
	bounds_max = Vector2i.ZERO
	border_tiles = 5
	room_width_cells = 0
	room_depth_cells = 0
	cell_size = 2.0
	tile_surface_y = 0.10
	chunk_size = 16
	chunk_count_x = 0
	chunk_count_y = 0

	tile_pixel_ids = PackedInt32Array()
	tile_grid_x = PackedInt32Array()
	tile_grid_y = PackedInt32Array()
	tile_palette_indices = PackedInt32Array()
	tile_completed = PackedByteArray()
	tile_local_x = PackedFloat32Array()
	tile_local_z = PackedFloat32Array()
	tile_chunk_indices = PackedInt32Array()

	palette_colors.clear()
	palette_codes.clear()
	palette_keys.clear()
	pixel_id_to_index.clear()
	grid_key_to_index.clear()
	chunk_tile_lists.clear()
	chunk_coords = PackedVector2Array()

func rebuild_lookup_tables() -> void:
	pixel_id_to_index.clear()
	grid_key_to_index.clear()

	for tile_index in range(tile_count):
		var pixel_id: int = int(tile_pixel_ids[tile_index])
		pixel_id_to_index[pixel_id] = tile_index
		grid_key_to_index[_make_grid_key(int(tile_grid_x[tile_index]), int(tile_grid_y[tile_index]))] = tile_index

func sync_completed_from_session_state(session_state: Resource) -> void:
	if session_state == null:
		return

	for tile_index in range(tile_count):
		var pixel_id: int = int(tile_pixel_ids[tile_index])
		tile_completed[tile_index] = 1 if session_state.is_tile_completed(pixel_id) else 0

func get_tile_index_by_pixel_id(pixel_id: int) -> int:
	if not pixel_id_to_index.has(pixel_id):
		return -1
	return int(pixel_id_to_index[pixel_id])

func get_tile_pixel_id(tile_index: int) -> int:
	if not is_valid_tile_index(tile_index):
		return -1
	return int(tile_pixel_ids[tile_index])

func get_tile_grid_pos(tile_index: int) -> Vector2i:
	if not is_valid_tile_index(tile_index):
		return Vector2i.ZERO
	return Vector2i(int(tile_grid_x[tile_index]), int(tile_grid_y[tile_index]))

func get_tile_palette_index(tile_index: int) -> int:
	if not is_valid_tile_index(tile_index):
		return -1
	return int(tile_palette_indices[tile_index])

func get_tile_color_code(tile_index: int) -> String:
	var palette_index: int = get_tile_palette_index(tile_index)
	if palette_index < 0 or palette_index >= palette_codes.size():
		return ""
	return str(palette_codes[palette_index])

func get_tile_color_key(tile_index: int) -> String:
	var palette_index: int = get_tile_palette_index(tile_index)
	if palette_index < 0 or palette_index >= palette_keys.size():
		return ""
	return str(palette_keys[palette_index])

func get_tile_source_color(tile_index: int) -> Color:
	var palette_index: int = get_tile_palette_index(tile_index)
	if palette_index < 0 or palette_index >= palette_colors.size():
		return Color.WHITE
	return palette_colors[palette_index]

func get_tile_local_position(tile_index: int) -> Vector3:
	if not is_valid_tile_index(tile_index):
		return Vector3.ZERO
	return Vector3(float(tile_local_x[tile_index]), tile_surface_y, float(tile_local_z[tile_index]))

func is_tile_completed_by_index(tile_index: int) -> bool:
	if not is_valid_tile_index(tile_index):
		return false
	return int(tile_completed[tile_index]) != 0

func set_tile_completed_by_index(tile_index: int, completed: bool) -> void:
	if not is_valid_tile_index(tile_index):
		return
	tile_completed[tile_index] = 1 if completed else 0

func get_completed_tile_count() -> int:
	var count: int = 0
	for tile_index in range(tile_count):
		if int(tile_completed[tile_index]) != 0:
			count += 1
	return count

func is_valid_tile_index(tile_index: int) -> bool:
	return tile_index >= 0 and tile_index < tile_count

func get_completed_pixel_ids_dictionary() -> Dictionary:
	var output: Dictionary = {}
	for tile_index in range(tile_count):
		if int(tile_completed[tile_index]) == 0:
			continue
		output[int(tile_pixel_ids[tile_index])] = true
	return output

func get_chunk_count() -> int:
	return chunk_tile_lists.size()

func is_valid_chunk_index(chunk_index: int) -> bool:
	return chunk_index >= 0 and chunk_index < get_chunk_count()

func get_chunk_index_for_tile(tile_index: int) -> int:
	if not is_valid_tile_index(tile_index):
		return -1
	return int(tile_chunk_indices[tile_index])

func get_chunk_tile_indices(chunk_index: int) -> PackedInt32Array:
	if not is_valid_chunk_index(chunk_index):
		return PackedInt32Array()
	return PackedInt32Array(chunk_tile_lists[chunk_index])

func get_chunk_coord(chunk_index: int) -> Vector2i:
	if not is_valid_chunk_index(chunk_index):
		return Vector2i.ZERO
	var coord: Vector2 = chunk_coords[chunk_index]
	return Vector2i(int(coord.x), int(coord.y))

func get_chunk_index_from_coords(chunk_x: int, chunk_y: int) -> int:
	if chunk_x < 0 or chunk_y < 0:
		return -1
	if chunk_x >= chunk_count_x or chunk_y >= chunk_count_y:
		return -1
	return (chunk_y * chunk_count_x) + chunk_x

func get_chunk_index_from_local_position(local_position: Vector3) -> int:
	if chunk_size <= 0 or room_width_cells <= 0 or room_depth_cells <= 0:
		return -1

	var room_center_x: float = (float(room_width_cells) - 1.0) * 0.5
	var room_center_z: float = (float(room_depth_cells) - 1.0) * 0.5

	var effective_cell_size: float = max(cell_size, 0.001)
	var cell_x: int = clampi(int(round((local_position.x / effective_cell_size) + room_center_x)), 0, room_width_cells - 1)
	var cell_z: int = clampi(int(round((local_position.z / effective_cell_size) + room_center_z)), 0, room_depth_cells - 1)

	var chunk_x: int = int(cell_x / chunk_size)
	var chunk_y: int = int(cell_z / chunk_size)
	return get_chunk_index_from_coords(chunk_x, chunk_y)

func _make_grid_key(grid_x: int, grid_y: int) -> String:
	return "%s:%s" % [grid_x, grid_y]