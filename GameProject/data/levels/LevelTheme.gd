extends Resource

## Controls the visual presentation of a generated level without changing layout.

@export var theme_id: String = ""
@export var theme_name: String = ""
@export var floor_color: Color = Color(0.16, 0.16, 0.16, 1.0)
@export var edge_floor_color: Color = Color(0.14, 0.14, 0.14, 1.0)
@export var border_floor_color: Color = Color(0.12, 0.12, 0.12, 1.0)
@export var wall_color: Color = Color(0.22, 0.22, 0.22, 1.0)
@export var tile_height: float = 0.25
@export var wall_height: float = 5.0
@export var wall_thickness: float = 0.5
@export var tile_muting_strength: float = 0.82
@export var cell_world_size: float = 2.0

## Weighted primitive wall variant controls for the modular wall pass.
@export var wall_variant_weight_common: int = 60
@export var wall_variant_weight_inset: int = 28
@export var wall_variant_weight_buttress: int = 12
@export var wall_small_room_disable_buttress_under_perimeter: int = 28
@export var wall_corner_post_scale: float = 1.18

## M21.4 theme authoring contract fields.
@export var authored_scene_pack_id: String = ""
@export_file("*.tscn") var play_floor_scene_path: String = ""
@export_file("*.tscn") var edge_floor_scene_path: String = ""
@export_file("*.tscn") var outer_floor_scene_path: String = ""
@export_file("*.tscn") var straight_wall_scene_a_path: String = ""
@export_file("*.tscn") var straight_wall_scene_b_path: String = ""
@export_file("*.tscn") var straight_wall_scene_c_path: String = ""
@export_file("*.tscn") var corner_post_scene_a_path: String = ""
@export_file("*.tscn") var corner_post_scene_b_path: String = ""
@export var expected_floor_piece_world_size: float = 2.0
@export var expected_wall_segment_world_length: float = 2.0
@export var expected_wall_forward_axis: String = "+Z"
@export var expected_origin_note: String = "Root centered on footprint, y=0 at floor contact."

func configure(
	new_theme_id: String,
	new_theme_name: String,
	new_floor_color: Color,
	new_border_floor_color: Color,
	new_wall_color: Color
) -> void:
	theme_id = new_theme_id
	theme_name = new_theme_name
	floor_color = new_floor_color
	border_floor_color = new_border_floor_color
	wall_color = new_wall_color
	edge_floor_color = floor_color.lerp(border_floor_color, 0.55)

func get_muted_color(source_color: Color) -> Color:
	var hsv_h: float = source_color.h
	var hsv_s: float = source_color.s
	var hsv_v: float = source_color.v

	var saturation_scale: float = clamp(1.0 - (tile_muting_strength * 0.72), 0.12, 1.0)
	var pastel_s: float = clamp(max(hsv_s * saturation_scale, 0.10), 0.0, 0.40)
	var pastel_v: float = clamp((hsv_v * 0.64) + 0.20, 0.20, 0.82)

	var pastel_base: Color = Color.from_hsv(hsv_h, pastel_s, pastel_v, source_color.a)
	var chalk_tint: Color = Color(0.80, 0.80, 0.80, source_color.a)

	var muted: Color = pastel_base.lerp(chalk_tint, 0.16)
	muted = muted.lerp(floor_color.lightened(0.10), 0.10)

	return Color(
		clamp(muted.r, 0.0, 1.0),
		clamp(muted.g, 0.0, 1.0),
		clamp(muted.b, 0.0, 1.0),
		source_color.a
	)

func has_authored_scene_contract() -> bool:
	return not authored_scene_pack_id.is_empty()

func get_authored_scene_paths() -> Array[String]:
	var output: Array[String] = []
	var raw_paths: Array[String] = [
		play_floor_scene_path,
		edge_floor_scene_path,
		outer_floor_scene_path,
		straight_wall_scene_a_path,
		straight_wall_scene_b_path,
		straight_wall_scene_c_path,
		corner_post_scene_a_path,
		corner_post_scene_b_path,
	]
	for path_value in raw_paths:
		if path_value.is_empty():
			continue
		output.append(path_value)
	return output

func get_floor_scene_path_for_zone(zone_name: String) -> String:
	match zone_name:
		"play":
			return play_floor_scene_path
		"edge":
			return edge_floor_scene_path
		"outer":
			return outer_floor_scene_path
		_:
			return ""

func to_dictionary() -> Dictionary:
	return {
		"theme_id": theme_id,
		"theme_name": theme_name,
		"floor_color": _color_to_dict(floor_color),
		"edge_floor_color": _color_to_dict(edge_floor_color),
		"border_floor_color": _color_to_dict(border_floor_color),
		"wall_color": _color_to_dict(wall_color),
		"tile_height": tile_height,
		"wall_height": wall_height,
		"wall_thickness": wall_thickness,
		"tile_muting_strength": tile_muting_strength,
		"cell_world_size": cell_world_size,
		"wall_variant_weight_common": wall_variant_weight_common,
		"wall_variant_weight_inset": wall_variant_weight_inset,
		"wall_variant_weight_buttress": wall_variant_weight_buttress,
		"wall_small_room_disable_buttress_under_perimeter": wall_small_room_disable_buttress_under_perimeter,
		"wall_corner_post_scale": wall_corner_post_scale,
		"authored_scene_pack_id": authored_scene_pack_id,
		"play_floor_scene_path": play_floor_scene_path,
		"edge_floor_scene_path": edge_floor_scene_path,
		"outer_floor_scene_path": outer_floor_scene_path,
		"straight_wall_scene_a_path": straight_wall_scene_a_path,
		"straight_wall_scene_b_path": straight_wall_scene_b_path,
		"straight_wall_scene_c_path": straight_wall_scene_c_path,
		"corner_post_scene_a_path": corner_post_scene_a_path,
		"corner_post_scene_b_path": corner_post_scene_b_path,
		"expected_floor_piece_world_size": expected_floor_piece_world_size,
		"expected_wall_segment_world_length": expected_wall_segment_world_length,
		"expected_wall_forward_axis": expected_wall_forward_axis,
		"expected_origin_note": expected_origin_note,
	}

static func from_dictionary(data: Dictionary) -> Resource:
	var theme: Resource = load("res://data/levels/LevelTheme.gd").new()
	theme.theme_id = str(data.get("theme_id", ""))
	theme.theme_name = str(data.get("theme_name", ""))
	theme.floor_color = _dict_to_color(Dictionary(data.get("floor_color", {})))
	theme.border_floor_color = _dict_to_color(Dictionary(data.get("border_floor_color", {})))
	if data.has("edge_floor_color"):
		theme.edge_floor_color = _dict_to_color(Dictionary(data.get("edge_floor_color", {})))
	else:
		theme.edge_floor_color = theme.floor_color.lerp(theme.border_floor_color, 0.55)
	theme.wall_color = _dict_to_color(Dictionary(data.get("wall_color", {})))
	theme.tile_height = float(data.get("tile_height", 0.25))
	theme.wall_height = float(data.get("wall_height", 5.0))
	theme.wall_thickness = float(data.get("wall_thickness", 0.5))
	theme.tile_muting_strength = float(data.get("tile_muting_strength", 0.82))
	theme.cell_world_size = float(data.get("cell_world_size", 2.0))
	theme.wall_variant_weight_common = int(data.get("wall_variant_weight_common", 60))
	theme.wall_variant_weight_inset = int(data.get("wall_variant_weight_inset", 28))
	theme.wall_variant_weight_buttress = int(data.get("wall_variant_weight_buttress", 12))
	theme.wall_small_room_disable_buttress_under_perimeter = int(data.get("wall_small_room_disable_buttress_under_perimeter", 28))
	theme.wall_corner_post_scale = float(data.get("wall_corner_post_scale", 1.18))
	theme.authored_scene_pack_id = str(data.get("authored_scene_pack_id", ""))
	theme.play_floor_scene_path = str(data.get("play_floor_scene_path", ""))
	theme.edge_floor_scene_path = str(data.get("edge_floor_scene_path", ""))
	theme.outer_floor_scene_path = str(data.get("outer_floor_scene_path", ""))
	theme.straight_wall_scene_a_path = str(data.get("straight_wall_scene_a_path", ""))
	theme.straight_wall_scene_b_path = str(data.get("straight_wall_scene_b_path", ""))
	theme.straight_wall_scene_c_path = str(data.get("straight_wall_scene_c_path", ""))
	theme.corner_post_scene_a_path = str(data.get("corner_post_scene_a_path", ""))
	theme.corner_post_scene_b_path = str(data.get("corner_post_scene_b_path", ""))
	theme.expected_floor_piece_world_size = float(data.get("expected_floor_piece_world_size", 2.0))
	theme.expected_wall_segment_world_length = float(data.get("expected_wall_segment_world_length", 2.0))
	theme.expected_wall_forward_axis = str(data.get("expected_wall_forward_axis", "+Z"))
	theme.expected_origin_note = str(data.get("expected_origin_note", "Root centered on footprint, y=0 at floor contact."))
	return theme

static func _color_to_dict(color_value: Color) -> Dictionary:
	return {
		"r": color_value.r,
		"g": color_value.g,
		"b": color_value.b,
		"a": color_value.a,
	}

static func _dict_to_color(data: Dictionary) -> Color:
	return Color(
		float(data.get("r", 1.0)),
		float(data.get("g", 1.0)),
		float(data.get("b", 1.0)),
		float(data.get("a", 1.0))
	)
