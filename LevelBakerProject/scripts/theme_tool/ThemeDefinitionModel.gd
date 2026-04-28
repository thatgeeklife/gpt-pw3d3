extends RefCounted

const DEFAULT_EXPECTED_ORIGIN_NOTE := "Root centered on footprint, y=0 at floor contact."

var data: Dictionary = {}
var current_file_path: String = ""
var is_dirty: bool = false

func reset_to_defaults() -> void:
	data = {
		"theme_id": "new_theme",
		"theme_name": "New Theme",
		"floor_color": {"r": 0.16, "g": 0.16, "b": 0.16, "a": 1.0},
		"edge_floor_color": {"r": 0.14, "g": 0.14, "b": 0.14, "a": 1.0},
		"border_floor_color": {"r": 0.12, "g": 0.12, "b": 0.12, "a": 1.0},
		"wall_color": {"r": 0.22, "g": 0.22, "b": 0.22, "a": 1.0},
		"tile_height": 0.25,
		"wall_height": 5.0,
		"wall_thickness": 0.5,
		"tile_muting_strength": 0.82,
		"cell_world_size": 2.0,
		"wall_variant_weight_common": 60,
		"wall_variant_weight_inset": 28,
		"wall_variant_weight_buttress": 12,
		"wall_small_room_disable_buttress_under_perimeter": 28,
		"wall_corner_post_scale": 1.18,
		"authored_scene_pack_id": "",
		"play_floor_scene_path": "",
		"edge_floor_scene_path": "",
		"outer_floor_scene_path": "",
		"straight_wall_scene_a_path": "",
		"straight_wall_scene_b_path": "",
		"straight_wall_scene_c_path": "",
		"corner_post_scene_a_path": "",
		"corner_post_scene_b_path": "",
		"expected_floor_piece_world_size": 2.0,
		"expected_wall_segment_world_length": 2.0,
		"expected_wall_forward_axis": "+Z",
		"expected_origin_note": DEFAULT_EXPECTED_ORIGIN_NOTE,
	}
	current_file_path = ""
	is_dirty = false

func load_from_dictionary(input_data: Dictionary, source_path: String = "") -> void:
	reset_to_defaults()
	for key in input_data.keys():
		data[key] = input_data[key]
	current_file_path = source_path
	is_dirty = false

func to_dictionary() -> Dictionary:
	return data.duplicate(true)

func set_value(key: String, value) -> void:
	data[key] = value
	is_dirty = true

func get_value(key: String, default_value = null):
	return data.get(key, default_value)

func get_color(key: String, fallback: Color) -> Color:
	var raw_value = data.get(key, null)
	if typeof(raw_value) == TYPE_DICTIONARY:
		var color_dict: Dictionary = raw_value
		return Color(
			float(color_dict.get("r", fallback.r)),
			float(color_dict.get("g", fallback.g)),
			float(color_dict.get("b", fallback.b)),
			float(color_dict.get("a", fallback.a))
		)
	return fallback

func set_color(key: String, color_value: Color) -> void:
	set_value(key, {
		"r": color_value.r,
		"g": color_value.g,
		"b": color_value.b,
		"a": color_value.a,
	})

func mark_saved(path_value: String) -> void:
	current_file_path = path_value
	is_dirty = false
