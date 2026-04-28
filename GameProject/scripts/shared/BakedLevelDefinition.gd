extends Resource
class_name BakedLevelDefinition

@export var level_id: String = ""
@export var level_name: String = ""
@export var theme_id: String = ""
@export var default_theme_id: String = ""
@export var required_level_ids: Array[String] = []
@export var required_dlc_id: String = ""
@export var source_image_path: String = ""
@export var image_width: int = 0
@export var image_height: int = 0
@export var visible_pixel_count: int = 0
@export var bounds_min: Vector2i = Vector2i.ZERO
@export var bounds_max: Vector2i = Vector2i.ZERO
@export var palette_colors: Array[Color] = []
@export var palette_codes: Array[String] = []
@export var palette_keys: Array[String] = []
@export var pixel_ids: PackedInt32Array = PackedInt32Array()
@export var grid_x: PackedInt32Array = PackedInt32Array()
@export var grid_y: PackedInt32Array = PackedInt32Array()
@export var palette_indices: PackedInt32Array = PackedInt32Array()

func clear() -> void:
	level_id = ""
	level_name = ""
	theme_id = ""
	default_theme_id = ""
	required_level_ids.clear()
	required_dlc_id = ""
	source_image_path = ""
	image_width = 0
	image_height = 0
	visible_pixel_count = 0
	bounds_min = Vector2i.ZERO
	bounds_max = Vector2i.ZERO
	palette_colors.clear()
	palette_codes.clear()
	palette_keys.clear()
	pixel_ids = PackedInt32Array()
	grid_x = PackedInt32Array()
	grid_y = PackedInt32Array()
	palette_indices = PackedInt32Array()

func get_palette_count() -> int:
	return palette_colors.size()

func get_pixel_count() -> int:
	return pixel_ids.size()

func is_valid_definition() -> bool:
	if level_id.is_empty():
		return false
	if level_name.is_empty():
		return false
	if theme_id.is_empty() and default_theme_id.is_empty():
		return false
	if image_width <= 0 or image_height <= 0:
		return false
	if visible_pixel_count < 0:
		return false
	if pixel_ids.size() != grid_x.size():
		return false
	if pixel_ids.size() != grid_y.size():
		return false
	if pixel_ids.size() != palette_indices.size():
		return false
	if palette_colors.size() != palette_codes.size():
		return false
	if palette_colors.size() != palette_keys.size():
		return false
	return true

func to_dictionary() -> Dictionary:
	var palette_color_dicts: Array = []
	for color_value in palette_colors:
		palette_color_dicts.append({"r": color_value.r, "g": color_value.g, "b": color_value.b, "a": color_value.a})
	return {
		"level_id": level_id,
		"level_name": level_name,
		"theme_id": theme_id,
		"default_theme_id": default_theme_id,
		"required_level_ids": required_level_ids.duplicate(),
		"required_dlc_id": required_dlc_id,
		"source_image_path": source_image_path,
		"image_width": image_width,
		"image_height": image_height,
		"visible_pixel_count": visible_pixel_count,
		"bounds_min": {"x": bounds_min.x, "y": bounds_min.y},
		"bounds_max": {"x": bounds_max.x, "y": bounds_max.y},
		"palette_colors": palette_color_dicts,
		"palette_codes": palette_codes.duplicate(),
		"palette_keys": palette_keys.duplicate(),
		"pixel_ids": pixel_ids,
		"grid_x": grid_x,
		"grid_y": grid_y,
		"palette_indices": palette_indices,
	}