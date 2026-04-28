extends RefCounted

const BAKED_LEVEL_DEFINITION_SCRIPT := preload("res://scripts/shared/BakedLevelDefinition.gd")

func build_from_image(absolute_source_path: String, source_image_path_for_resource: String, level_id: String, level_name: String, theme_id: String) -> Resource:
	var image := Image.new()
	var load_error: Error = image.load(absolute_source_path)
	if load_error != OK:
		return null

	var baked: Resource = BAKED_LEVEL_DEFINITION_SCRIPT.new()
	baked.clear()
	baked.level_id = level_id.strip_edges()
	baked.level_name = level_name.strip_edges()
	baked.theme_id = theme_id.strip_edges()
	baked.default_theme_id = baked.theme_id
	baked.source_image_path = source_image_path_for_resource
	baked.image_width = image.get_width()
	baked.image_height = image.get_height()

	var bounds_min := Vector2i(2147483647, 2147483647)
	var bounds_max := Vector2i(-2147483648, -2147483648)
	var palette_lookup: Dictionary = {}

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var color_key: String = _make_color_key(pixel)
			var palette_index: int = int(palette_lookup.get(color_key, -1))
			if palette_index == -1:
				palette_index = baked.palette_colors.size()
				palette_lookup[color_key] = palette_index
				baked.palette_colors.append(pixel)
				baked.palette_keys.append(color_key)
				baked.palette_codes.append(_make_palette_code(palette_index))
			baked.pixel_ids.append(_make_pixel_id(x, y, image.get_width()))
			baked.grid_x.append(x)
			baked.grid_y.append(y)
			baked.palette_indices.append(palette_index)
			bounds_min.x = mini(bounds_min.x, x)
			bounds_min.y = mini(bounds_min.y, y)
			bounds_max.x = maxi(bounds_max.x, x)
			bounds_max.y = maxi(bounds_max.y, y)

	baked.visible_pixel_count = baked.pixel_ids.size()
	if baked.visible_pixel_count > 0:
		baked.bounds_min = bounds_min
		baked.bounds_max = bounds_max
	return baked

func save_baked_definition(baked_definition: Resource, absolute_output_path: String) -> Error:
	return _save_dictionary_text(baked_definition.to_dictionary(), absolute_output_path)

func save_baked_definition_json(baked_definition: Resource, absolute_output_path: String) -> Error:
	return _save_dictionary_text(baked_definition.to_dictionary(), absolute_output_path)

func _save_dictionary_text(payload: Dictionary, absolute_output_path: String) -> Error:
	var output_dir: String = absolute_output_path.get_base_dir()
	if not output_dir.is_empty():
		var make_error: Error = DirAccess.make_dir_recursive_absolute(output_dir)
		if make_error != OK and make_error != ERR_ALREADY_EXISTS:
			return make_error
	var file: FileAccess = FileAccess.open(absolute_output_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	return OK

func _make_pixel_id(x: int, y: int, source_width: int) -> int:
	return (y * source_width) + x

func _make_color_key(color_value: Color) -> String:
	return "%d_%d_%d_%d" % [int(round(color_value.r * 255.0)), int(round(color_value.g * 255.0)), int(round(color_value.b * 255.0)), int(round(color_value.a * 255.0))]

func _make_palette_code(index: int) -> String:
	var letter_block: int = int(index % 26)
	var number_block: int = int(index / 26) + 1
	return "%s%s" % [char(65 + letter_block), number_block]