extends RefCounted

## Builds ordered perimeter wall slots and corner posts for the current room footprint.

func build_layout(
	bounds: Dictionary,
	border_tiles: int,
	cell_world_size: float,
	wall_thickness: float
) -> Dictionary:
	var room_width_cells: int = int(bounds.get("occupied_width", 0)) + (border_tiles * 2)
	var room_depth_cells: int = int(bounds.get("occupied_height", 0)) + (border_tiles * 2)
	var room_world_width: float = float(room_width_cells) * cell_world_size
	var room_world_depth: float = float(room_depth_cells) * cell_world_size
	var perimeter_cells: int = maxi((room_width_cells * 2) + (room_depth_cells * 2) - 4, 0)

	var straight_slots: Array = []
	var corner_slots: Array = []
	var next_slot_index: int = 0

	for cell_x in range(room_width_cells):
		straight_slots.append(_make_straight_slot(
			next_slot_index,
			"north_run",
			"straight_north",
			Vector3(_cell_offset_x(cell_x, room_width_cells, cell_world_size), 0.0, -(room_world_depth * 0.5) - (wall_thickness * 0.5)),
			"x",
			cell_world_size,
			perimeter_cells
		))
		next_slot_index += 1

	for cell_x in range(room_width_cells):
		straight_slots.append(_make_straight_slot(
			next_slot_index,
			"south_run",
			"straight_south",
			Vector3(_cell_offset_x(cell_x, room_width_cells, cell_world_size), 0.0, (room_world_depth * 0.5) + (wall_thickness * 0.5)),
			"x",
			cell_world_size,
			perimeter_cells
		))
		next_slot_index += 1

	for cell_z in range(room_depth_cells):
		straight_slots.append(_make_straight_slot(
			next_slot_index,
			"west_run",
			"straight_west",
			Vector3(-(room_world_width * 0.5) - (wall_thickness * 0.5), 0.0, _cell_offset_z(cell_z, room_depth_cells, cell_world_size)),
			"z",
			cell_world_size,
			perimeter_cells
		))
		next_slot_index += 1

	for cell_z in range(room_depth_cells):
		straight_slots.append(_make_straight_slot(
			next_slot_index,
			"east_run",
			"straight_east",
			Vector3((room_world_width * 0.5) + (wall_thickness * 0.5), 0.0, _cell_offset_z(cell_z, room_depth_cells, cell_world_size)),
			"z",
			cell_world_size,
			perimeter_cells
		))
		next_slot_index += 1

	corner_slots.append(_make_corner_slot(next_slot_index, "corner_nw", Vector3(-(room_world_width * 0.5) - (wall_thickness * 0.5), 0.0, -(room_world_depth * 0.5) - (wall_thickness * 0.5)), perimeter_cells))
	next_slot_index += 1
	corner_slots.append(_make_corner_slot(next_slot_index, "corner_ne", Vector3((room_world_width * 0.5) + (wall_thickness * 0.5), 0.0, -(room_world_depth * 0.5) - (wall_thickness * 0.5)), perimeter_cells))
	next_slot_index += 1
	corner_slots.append(_make_corner_slot(next_slot_index, "corner_sw", Vector3(-(room_world_width * 0.5) - (wall_thickness * 0.5), 0.0, (room_world_depth * 0.5) + (wall_thickness * 0.5)), perimeter_cells))
	next_slot_index += 1
	corner_slots.append(_make_corner_slot(next_slot_index, "corner_se", Vector3((room_world_width * 0.5) + (wall_thickness * 0.5), 0.0, (room_world_depth * 0.5) + (wall_thickness * 0.5)), perimeter_cells))

	return {
		"room_width_cells": room_width_cells,
		"room_depth_cells": room_depth_cells,
		"room_world_width": room_world_width,
		"room_world_depth": room_world_depth,
		"perimeter_cells": perimeter_cells,
		"straight_slots": straight_slots,
		"corner_slots": corner_slots,
	}

func _make_straight_slot(
	slot_index: int,
	run_id: String,
	slot_category: String,
	world_position: Vector3,
	axis: String,
	segment_length: float,
	perimeter_cells: int
) -> Dictionary:
	return {
		"slot_index": slot_index,
		"run_id": run_id,
		"slot_category": slot_category,
		"world_position": world_position,
		"axis": axis,
		"segment_length": segment_length,
		"perimeter_cells": perimeter_cells,
	}

func _make_corner_slot(
	slot_index: int,
	slot_category: String,
	world_position: Vector3,
	perimeter_cells: int
) -> Dictionary:
	return {
		"slot_index": slot_index,
		"run_id": slot_category,
		"slot_category": slot_category,
		"world_position": world_position,
		"axis": "corner",
		"segment_length": 0.0,
		"perimeter_cells": perimeter_cells,
	}

func _cell_offset_x(cell_x: int, room_width_cells: int, cell_world_size: float) -> float:
	var room_center_x: float = (float(room_width_cells) - 1.0) * 0.5
	return (float(cell_x) - room_center_x) * cell_world_size

func _cell_offset_z(cell_z: int, room_depth_cells: int, cell_world_size: float) -> float:
	var room_center_z: float = (float(room_depth_cells) - 1.0) * 0.5
	return (float(cell_z) - room_center_z) * cell_world_size
