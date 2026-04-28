extends RefCounted

const LEVEL_DEFINITION_SCRIPT := preload("res://data/levels/LevelDefinition.gd")
const LEVEL_PIXEL_DATA_SCRIPT := preload("res://data/levels/LevelPixelData.gd")

func baked_dictionary_to_legacy_definition(data: Dictionary) -> Resource:
	if typeof(data) != TYPE_DICTIONARY:
		return null

	var definition: Resource = LEVEL_DEFINITION_SCRIPT.new()
	var image_width: int = int(data.get("image_width", data.get("source_width", 0)))
	var image_height: int = int(data.get("image_height", data.get("source_height", 0)))
	var default_theme_id: String = str(data.get("default_theme_id", data.get("theme_id", "")))
	var required_level_ids: Array[String] = Array(data.get("required_level_ids", []), TYPE_STRING, "", null)
	var required_dlc_id: String = str(data.get("required_dlc_id", ""))

	definition.configure(
		str(data.get("level_id", "")),
		str(data.get("level_name", "")),
		image_width,
		image_height,
		default_theme_id,
		required_level_ids,
		required_dlc_id
	)

	var palette_colors: Array = Array(data.get("palette_colors", []))
	var palette_codes: Array = Array(data.get("palette_codes", []))
	var palette_keys: Array = Array(data.get("palette_keys", []))
	var pixel_ids: Array = Array(data.get("pixel_ids", []))
	var grid_x: Array = Array(data.get("grid_x", []))
	var grid_y: Array = Array(data.get("grid_y", []))
	var palette_indices: Array = Array(data.get("palette_indices", []))

	var total: int = pixel_ids.size()
	if grid_x.size() != total or grid_y.size() != total or palette_indices.size() != total:
		return definition

	for i in range(total):
		var palette_index: int = int(palette_indices[i])
		if palette_index < 0 or palette_index >= palette_colors.size():
			continue

		var pixel: Resource = LEVEL_PIXEL_DATA_SCRIPT.new()
		pixel.configure(
			int(pixel_ids[i]),
			Vector2i(int(grid_x[i]), int(grid_y[i])),
			_color_from_baked_value(palette_colors[palette_index]),
			str(palette_keys[palette_index]) if palette_index < palette_keys.size() else "",
			str(palette_codes[palette_index]) if palette_index < palette_codes.size() else ""
		)
		definition.add_pixel(pixel)

	return definition

func load_baked_text_definition_as_legacy_definition(absolute_path: String) -> Resource:
	if not FileAccess.file_exists(absolute_path):
		return null

	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return null

	var text: String = file.get_as_text()
	file.close()

	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return null

	# JSON-text baked files written into .tres/.json start with "{"
	if trimmed.begins_with("{"):
		var parsed = JSON.parse_string(trimmed)
		if typeof(parsed) != TYPE_DICTIONARY:
			return null
		return baked_dictionary_to_legacy_definition(parsed)

	# Real Godot text resources start with "[" such as [gd_resource]
	if trimmed.begins_with("["):
		var resource_path: String = _absolute_path_to_resource_path(absolute_path)
		if resource_path.is_empty():
			return null

		var baked_resource: Resource = ResourceLoader.load(resource_path)
		if baked_resource == null:
			return null

		return _baked_resource_to_legacy_definition(baked_resource)

	return null

func _baked_resource_to_legacy_definition(baked_resource: Resource) -> Resource:
	if baked_resource == null:
		return null
	if not _resource_has_baked_fields(baked_resource):
		return null

	var data := {
		"level_id": baked_resource.get("level_id"),
		"level_name": baked_resource.get("level_name"),
		"theme_id": baked_resource.get("theme_id"),
		"default_theme_id": baked_resource.get("default_theme_id"),
		"required_level_ids": baked_resource.get("required_level_ids"),
		"required_dlc_id": baked_resource.get("required_dlc_id"),
		"source_image_path": baked_resource.get("source_image_path"),
		"image_width": baked_resource.get("image_width"),
		"image_height": baked_resource.get("image_height"),
		"visible_pixel_count": baked_resource.get("visible_pixel_count"),
		"bounds_min": baked_resource.get("bounds_min"),
		"bounds_max": baked_resource.get("bounds_max"),
		"palette_colors": baked_resource.get("palette_colors"),
		"palette_codes": baked_resource.get("palette_codes"),
		"palette_keys": baked_resource.get("palette_keys"),
		"pixel_ids": baked_resource.get("pixel_ids"),
		"grid_x": baked_resource.get("grid_x"),
		"grid_y": baked_resource.get("grid_y"),
		"palette_indices": baked_resource.get("palette_indices"),
	}

	var bounds_min_value = data["bounds_min"]
	if bounds_min_value is Vector2i:
		data["bounds_min"] = {"x": bounds_min_value.x, "y": bounds_min_value.y}
	var bounds_max_value = data["bounds_max"]
	if bounds_max_value is Vector2i:
		data["bounds_max"] = {"x": bounds_max_value.x, "y": bounds_max_value.y}

	return baked_dictionary_to_legacy_definition(data)

func _resource_has_baked_fields(resource_value: Resource) -> bool:
	var required_fields: Array[String] = [
		"level_id",
		"level_name",
		"image_width",
		"image_height",
		"palette_colors",
		"pixel_ids",
		"grid_x",
		"grid_y",
		"palette_indices",
	]
	for field_name in required_fields:
		if resource_value.get(field_name) == null:
			return false
	return true

func _absolute_path_to_resource_path(absolute_path: String) -> String:
	var clean_absolute: String = absolute_path.simplify_path()
	var project_root: String = ProjectSettings.globalize_path("res://").simplify_path()
	if clean_absolute.begins_with(project_root):
		var suffix: String = clean_absolute.trim_prefix(project_root).trim_prefix("/")
		return "res://%s" % suffix

	var shared_root: String = project_root.path_join("../SharedLevelContent").simplify_path()
	if clean_absolute.begins_with(shared_root):
		var shared_suffix: String = clean_absolute.trim_prefix(shared_root).trim_prefix("/")
		return "res://../SharedLevelContent/%s" % shared_suffix

	return ""

func _color_from_baked_value(value) -> Color:
	if typeof(value) == TYPE_COLOR:
		return value

	if typeof(value) == TYPE_DICTIONARY:
		var color_dict: Dictionary = value
		return Color(
			float(color_dict.get("r", 1.0)),
			float(color_dict.get("g", 1.0)),
			float(color_dict.get("b", 1.0)),
			float(color_dict.get("a", 1.0))
		)

	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 4:
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))

	return Color.WHITE
