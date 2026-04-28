extends RefCounted

## Converts a LevelDefinition and current session completion state
## into a data-driven runtime model for gameplay queries.

const LEVEL_RUNTIME_DATA_SCRIPT := preload("res://systems/level_runtime/LevelRuntimeData.gd")
const DEFAULT_BORDER_TILES := 5
const DEFAULT_CHUNK_SIZE := 16
const DEFAULT_CELL_WORLD_SIZE := 2.0
const TILE_SURFACE_Y := 0.10

func build_runtime_data(
	level_definition: Resource,
	theme: Resource,
	session_state: Resource,
	border_tiles: int = DEFAULT_BORDER_TILES,
	chunk_size: int = DEFAULT_CHUNK_SIZE
) -> Resource:
	if level_definition == null:
		return null

	var bounds: Dictionary = _compute_bounds(level_definition)
	if not bool(bounds.get("has_pixels", false)):
		return null

	var runtime_data: Resource = LEVEL_RUNTIME_DATA_SCRIPT.new()
	runtime_data.clear()
	runtime_data.level_id = str(level_definition.level_id)
	runtime_data.level_name = str(level_definition.level_name)
	runtime_data.theme_id = str(theme.theme_id) if theme != null else ""
	runtime_data.bounds_min = Vector2i(int(bounds.get("min_x", 0)), int(bounds.get("min_y", 0)))
	runtime_data.bounds_max = Vector2i(int(bounds.get("max_x", 0)), int(bounds.get("max_y", 0)))
	runtime_data.border_tiles = border_tiles
	runtime_data.room_width_cells = int(bounds.get("occupied_width", 0)) + (border_tiles * 2)
	runtime_data.room_depth_cells = int(bounds.get("occupied_height", 0)) + (border_tiles * 2)
	runtime_data.tile_surface_y = TILE_SURFACE_Y
	runtime_data.cell_size = _get_cell_world_size(theme)
	runtime_data.chunk_size = max(chunk_size, 1)
	runtime_data.chunk_count_x = int(ceil(float(runtime_data.room_width_cells) / float(runtime_data.chunk_size)))
	runtime_data.chunk_count_y = int(ceil(float(runtime_data.room_depth_cells) / float(runtime_data.chunk_size)))

	var palette_index_by_key: Dictionary = {}
	var tile_pixel_ids: PackedInt32Array = PackedInt32Array()
	var tile_grid_x: PackedInt32Array = PackedInt32Array()
	var tile_grid_y: PackedInt32Array = PackedInt32Array()
	var tile_palette_indices: PackedInt32Array = PackedInt32Array()
	var tile_completed: PackedByteArray = PackedByteArray()
	var tile_local_x: PackedFloat32Array = PackedFloat32Array()
	var tile_local_z: PackedFloat32Array = PackedFloat32Array()
	var tile_chunk_indices: PackedInt32Array = PackedInt32Array()

	var chunk_lists: Array = []
	var chunk_coords: PackedVector2Array = PackedVector2Array()
	var chunk_count: int = runtime_data.chunk_count_x * runtime_data.chunk_count_y
	for chunk_index in range(chunk_count):
		chunk_lists.append(PackedInt32Array())
		var chunk_x: int = chunk_index % runtime_data.chunk_count_x
		var chunk_y: int = int(chunk_index / runtime_data.chunk_count_x)
		chunk_coords.append(Vector2(chunk_x, chunk_y))

	var runtime_tile_index: int = 0
	for pixel_resource in level_definition.pixels:
		if pixel_resource == null:
			continue

		var color_key: String = str(pixel_resource.color_key)
		var palette_index: int = -1
		if palette_index_by_key.has(color_key):
			palette_index = int(palette_index_by_key[color_key])
		else:
			palette_index = runtime_data.palette_colors.size()
			palette_index_by_key[color_key] = palette_index
			runtime_data.palette_colors.append(pixel_resource.source_color)
			runtime_data.palette_codes.append(str(pixel_resource.color_code))
			runtime_data.palette_keys.append(color_key)

		var cell_pos: Vector2i = _grid_to_cell_position(pixel_resource.grid_pos, bounds, border_tiles)
		var local_pos: Vector3 = _cell_to_local_position(cell_pos, runtime_data.room_width_cells, runtime_data.room_depth_cells)
		var chunk_x: int = int(cell_pos.x / runtime_data.chunk_size)
		var chunk_y: int = int(cell_pos.y / runtime_data.chunk_size)
		var chunk_index: int = (chunk_y * runtime_data.chunk_count_x) + chunk_x

		tile_pixel_ids.append(int(pixel_resource.pixel_id))
		tile_grid_x.append(int(pixel_resource.grid_pos.x))
		tile_grid_y.append(int(pixel_resource.grid_pos.y))
		tile_palette_indices.append(palette_index)
		tile_completed.append(1 if (session_state != null and session_state.is_tile_completed(int(pixel_resource.pixel_id))) else 0)
		tile_local_x.append(float(local_pos.x))
		tile_local_z.append(float(local_pos.z))
		tile_chunk_indices.append(chunk_index)

		var chunk_list: PackedInt32Array = PackedInt32Array(chunk_lists[chunk_index])
		chunk_list.append(runtime_tile_index)
		chunk_lists[chunk_index] = chunk_list

		runtime_tile_index += 1

	runtime_data.tile_pixel_ids = tile_pixel_ids
	runtime_data.tile_grid_x = tile_grid_x
	runtime_data.tile_grid_y = tile_grid_y
	runtime_data.tile_palette_indices = tile_palette_indices
	runtime_data.tile_completed = tile_completed
	runtime_data.tile_local_x = tile_local_x
	runtime_data.tile_local_z = tile_local_z
	runtime_data.tile_chunk_indices = tile_chunk_indices
	runtime_data.tile_count = tile_pixel_ids.size()
	runtime_data.chunk_tile_lists = chunk_lists
	runtime_data.chunk_coords = chunk_coords
	runtime_data.rebuild_lookup_tables()

	return runtime_data

func _compute_bounds(level_definition: Resource) -> Dictionary:
	var has_pixels: bool = false
	var min_x: int = 0
	var min_y: int = 0
	var max_x: int = 0
	var max_y: int = 0

	for pixel_resource in level_definition.pixels:
		if pixel_resource == null:
			continue

		var grid_pos: Vector2i = pixel_resource.grid_pos
		if not has_pixels:
			has_pixels = true
			min_x = grid_pos.x
			min_y = grid_pos.y
			max_x = grid_pos.x
			max_y = grid_pos.y
		else:
			min_x = mini(min_x, grid_pos.x)
			min_y = mini(min_y, grid_pos.y)
			max_x = maxi(max_x, grid_pos.x)
			max_y = maxi(max_y, grid_pos.y)

	if not has_pixels:
		return {"has_pixels": false}

	return {
		"has_pixels": true,
		"min_x": min_x,
		"min_y": min_y,
		"max_x": max_x,
		"max_y": max_y,
		"occupied_width": (max_x - min_x) + 1,
		"occupied_height": (max_y - min_y) + 1,
	}

func _grid_to_cell_position(grid_pos: Vector2i, bounds: Dictionary, border_tiles: int) -> Vector2i:
	return Vector2i(
		(grid_pos.x - int(bounds.get("min_x", 0))) + border_tiles,
		(grid_pos.y - int(bounds.get("min_y", 0))) + border_tiles
	)

func _cell_to_local_position(cell_pos: Vector2i, room_width_cells: int, room_depth_cells: int) -> Vector3:
	var room_center_x: float = (float(room_width_cells) - 1.0) * 0.5
	var room_center_z: float = (float(room_depth_cells) - 1.0) * 0.5
	var cell_size: float = DEFAULT_CELL_WORLD_SIZE

	return Vector3(
		(float(cell_pos.x) - room_center_x) * cell_size,
		0.0,
		(float(cell_pos.y) - room_center_z) * cell_size
	)

func _get_cell_world_size(theme: Resource) -> float:
	if theme != null:
		var value = theme.get("cell_world_size")
		if value != null:
			return max(float(value), 0.5)
	return DEFAULT_CELL_WORLD_SIZE
