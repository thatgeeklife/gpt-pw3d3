extends RefCounted

## Imports a source image into a static LevelDefinition.
## Every non-transparent pixel becomes one LevelPixelData entry.
## This importer does not generate runtime geometry. It only creates data.

const LEVEL_DEFINITION_SCRIPT := "res://data/levels/LevelDefinition.gd"
const LEVEL_PIXEL_DATA_SCRIPT := "res://data/levels/LevelPixelData.gd"

static func import_image_to_definition(
	image_path: String,
	level_id: String,
	level_name: String,
	default_theme_id: String,
	required_level_ids: Array[String] = [],
	required_dlc_id: String = "",
	alpha_threshold: float = 0.001
) -> Resource:
	var image: Image = _load_image_from_resource_path(image_path)
	if image == null:
		push_error("LevelImageImporter: failed to load image resource: %s" % image_path)
		return null

	return import_image_data_to_definition(
		image,
		level_id,
		level_name,
		default_theme_id,
		required_level_ids,
		required_dlc_id,
		alpha_threshold
	)

static func _load_image_from_resource_path(image_path: String) -> Image:
	var resource = ResourceLoader.load(image_path)
	if resource == null:
		return null

	if resource is Image:
		return resource

	if resource is Texture2D:
		return resource.get_image()

	return null

static func import_image_data_to_definition(
	image: Image,
	level_id: String,
	level_name: String,
	default_theme_id: String,
	required_level_ids: Array[String] = [],
	required_dlc_id: String = "",
	alpha_threshold: float = 0.001
) -> Resource:
	if image == null:
		push_error("LevelImageImporter: image data was null.")
		return null

	var definition: Resource = load(LEVEL_DEFINITION_SCRIPT).new()
	definition.configure(
		level_id,
		level_name,
		image.get_width(),
		image.get_height(),
		default_theme_id,
		required_level_ids,
		required_dlc_id
	)

	var color_code_by_key: Dictionary = {}
	var next_color_index: int = 0

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var source_color: Color = image.get_pixel(x, y)
			if source_color.a <= alpha_threshold:
				continue

			var color_key: String = _make_color_key(source_color)
			if not color_code_by_key.has(color_key):
				color_code_by_key[color_key] = _make_color_code(next_color_index)
				next_color_index += 1

			var pixel_id: int = _make_pixel_id(x, y, image.get_width())
			var pixel: Resource = load(LEVEL_PIXEL_DATA_SCRIPT).new()
			pixel.configure(
				pixel_id,
				Vector2i(x, y),
				source_color,
				color_key,
				str(color_code_by_key[color_key])
			)
			definition.add_pixel(pixel)

	return definition

static func _make_pixel_id(x: int, y: int, source_width: int) -> int:
	return (y * source_width) + x

static func _make_color_key(color_value: Color) -> String:
	var r: int = int(round(color_value.r * 255.0))
	var g: int = int(round(color_value.g * 255.0))
	var b: int = int(round(color_value.b * 255.0))
	var a: int = int(round(color_value.a * 255.0))
	return "%03d_%03d_%03d_%03d" % [r, g, b, a]

static func _make_color_code(index: int) -> String:
	return "C%s" % _to_base36(index)

static func _to_base36(value: int) -> String:
	var digits: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var remaining: int = max(value, 0)
	if remaining == 0:
		return "0"

	var output: String = ""
	while remaining > 0:
		var digit_index: int = remaining % 36
		output = digits.substr(digit_index, 1) + output
		remaining = int(remaining / 36)

	return output

static func validate_definition(definition: Resource) -> Dictionary:
	var result := {
		"is_valid": true,
		"errors": [],
		"pixel_count": 0,
		"duplicate_pixel_ids": [],
	}

	if definition == null:
		result["is_valid"] = false
		result["errors"].append("Definition is null.")
		return result

	if str(definition.level_id).is_empty():
		result["is_valid"] = false
		result["errors"].append("Level id is empty.")

	if int(definition.source_width) <= 0:
		result["is_valid"] = false
		result["errors"].append("Source width must be greater than zero.")

	if int(definition.source_height) <= 0:
		result["is_valid"] = false
		result["errors"].append("Source height must be greater than zero.")

	var seen_ids: Dictionary = {}
	var duplicate_ids: Array[int] = []

	for pixel in definition.pixels:
		if pixel == null:
			continue

		var pixel_id: int = int(pixel.pixel_id)
		if seen_ids.has(pixel_id):
			duplicate_ids.append(pixel_id)
		else:
			seen_ids[pixel_id] = true

	result["pixel_count"] = seen_ids.size()
	result["duplicate_pixel_ids"] = duplicate_ids

	if not duplicate_ids.is_empty():
		result["is_valid"] = false
		result["errors"].append("Duplicate pixel ids found.")

	if int(result["pixel_count"]) <= 0:
		result["is_valid"] = false
		result["errors"].append("Definition contains no visible pixels.")

	return result

static func definition_to_json_text(definition: Resource) -> String:
	if definition == null:
		return "{}"

	if not definition.has_method("to_dictionary"):
		return "{}"

	return JSON.stringify(definition.to_dictionary(), "\t")

static func save_definition_as_json(definition: Resource, output_path: String) -> int:
	if definition == null:
		return ERR_INVALID_PARAMETER

	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(definition_to_json_text(definition))
	file.flush()
	file.close()
	return OK

static func load_definition_from_json(json_path: String) -> Resource:
	if not FileAccess.file_exists(json_path):
		push_error("LevelImageImporter: JSON file does not exist: %s" % json_path)
		return null

	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("LevelImageImporter: failed opening JSON file: %s" % json_path)
		return null

	var json_text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("LevelImageImporter: JSON root was not a dictionary: %s" % json_path)
		return null

	return load(LEVEL_DEFINITION_SCRIPT).from_dictionary(parsed)

static func get_visible_pixel_count_from_image(image_path: String, alpha_threshold: float = 0.001) -> int:
	var image: Image = _load_image_from_resource_path(image_path)
	if image == null:
		return 0

	var count: int = 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > alpha_threshold:
				count += 1

	return count