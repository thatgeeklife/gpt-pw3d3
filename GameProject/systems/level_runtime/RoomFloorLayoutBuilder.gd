extends RefCounted

## Classifies floor cells into play / edge / outer zones and converts them to local-space positions.

const DEFAULT_EDGE_RING_CELLS := 1

func build_layout(
	bounds: Dictionary,
	border_tiles: int,
	cell_world_size: float,
	edge_ring_cells: int = DEFAULT_EDGE_RING_CELLS
) -> Dictionary:
	var room_width_cells: int = int(bounds.get("occupied_width", 0)) + (border_tiles * 2)
	var room_depth_cells: int = int(bounds.get("occupied_height", 0)) + (border_tiles * 2)

	var play_min_x: int = border_tiles
	var play_min_z: int = border_tiles
	var play_max_x: int = play_min_x + int(bounds.get("occupied_width", 0)) - 1
	var play_max_z: int = play_min_z + int(bounds.get("occupied_height", 0)) - 1

	var edge_min_x: int = maxi(play_min_x - edge_ring_cells, 0)
	var edge_min_z: int = maxi(play_min_z - edge_ring_cells, 0)
	var edge_max_x: int = mini(play_max_x + edge_ring_cells, room_width_cells - 1)
	var edge_max_z: int = mini(play_max_z + edge_ring_cells, room_depth_cells - 1)

	var play_positions: Array = []
	var edge_positions: Array = []
	var outer_positions: Array = []

	for cell_z in range(room_depth_cells):
		for cell_x in range(room_width_cells):
			var local_pos: Vector3 = _cell_to_local_position(cell_x, cell_z, room_width_cells, room_depth_cells, cell_world_size)

			if _is_inside_rect(cell_x, cell_z, play_min_x, play_min_z, play_max_x, play_max_z):
				play_positions.append(local_pos)
			elif _is_inside_rect(cell_x, cell_z, edge_min_x, edge_min_z, edge_max_x, edge_max_z):
				edge_positions.append(local_pos)
			else:
				outer_positions.append(local_pos)

	return {
		"room_width_cells": room_width_cells,
		"room_depth_cells": room_depth_cells,
		"play_positions": play_positions,
		"edge_positions": edge_positions,
		"outer_positions": outer_positions,
	}

func _cell_to_local_position(
	cell_x: int,
	cell_z: int,
	room_width_cells: int,
	room_depth_cells: int,
	cell_world_size: float
) -> Vector3:
	var room_center_x: float = (float(room_width_cells) - 1.0) * 0.5
	var room_center_z: float = (float(room_depth_cells) - 1.0) * 0.5

	return Vector3(
		(float(cell_x) - room_center_x) * cell_world_size,
		0.0,
		(float(cell_z) - room_center_z) * cell_world_size
	)

func _is_inside_rect(
	cell_x: int,
	cell_z: int,
	min_x: int,
	min_z: int,
	max_x: int,
	max_z: int
) -> bool:
	return cell_x >= min_x and cell_x <= max_x and cell_z >= min_z and cell_z <= max_z
