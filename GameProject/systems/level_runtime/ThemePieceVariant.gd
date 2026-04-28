extends Resource

## Lightweight weighted wall-piece variant entry for deterministic selection.

@export var variant_id: String = ""
@export var weight: int = 1
@export var min_perimeter_cells: int = 0
@export var max_perimeter_cells: int = 999999
@export var length_scale: float = 1.0
@export var height_scale: float = 1.0
@export var thickness_scale: float = 1.0
@export var color_mix: float = 0.0
@export var color_target: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var roughness: float = 0.95
@export_file("*.tscn") var scene_path: String = ""

func configure(
	new_variant_id: String,
	new_weight: int,
	new_min_perimeter_cells: int,
	new_max_perimeter_cells: int,
	new_length_scale: float,
	new_height_scale: float,
	new_thickness_scale: float,
	new_color_mix: float,
	new_color_target: Color,
	new_roughness: float,
	new_scene_path: String = ""
) -> void:
	variant_id = new_variant_id
	weight = maxi(new_weight, 0)
	min_perimeter_cells = new_min_perimeter_cells
	max_perimeter_cells = new_max_perimeter_cells
	length_scale = new_length_scale
	height_scale = new_height_scale
	thickness_scale = new_thickness_scale
	color_mix = new_color_mix
	color_target = new_color_target
	roughness = new_roughness
	scene_path = new_scene_path

func is_allowed_for_perimeter(perimeter_cells: int) -> bool:
	return perimeter_cells >= min_perimeter_cells and perimeter_cells <= max_perimeter_cells

func has_scene_path() -> bool:
	return not scene_path.is_empty()
