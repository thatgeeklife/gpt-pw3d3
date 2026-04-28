extends RefCounted

const MAX_VISIBLE_PIXELS_WARNING: int = 12000

func validate_inputs(source_image_path: String, level_id: String, level_name: String, theme_id: String, output_path: String) -> Dictionary:
	var lines: Array[String] = []
	var has_error: bool = false

	if source_image_path.strip_edges().is_empty():
		lines.append("- Missing source image path.")
		has_error = true
	else:
		lines.append("- Source image path set.")

	if level_id.strip_edges().is_empty():
		lines.append("- Missing level id.")
		has_error = true
	else:
		lines.append("- Level id set.")

	if level_name.strip_edges().is_empty():
		lines.append("- Missing level name.")
		has_error = true
	else:
		lines.append("- Level name set.")

	if theme_id.strip_edges().is_empty():
		lines.append("- Missing theme id.")
		has_error = true
	else:
		lines.append("- Theme id set.")

	if output_path.strip_edges().is_empty():
		lines.append("- Missing output path.")
		has_error = true
	else:
		lines.append("- Output path set.")

	return {
		"is_valid": not has_error,
		"lines": lines,
	}

func validate_image(absolute_source_path: String, image: Image) -> Dictionary:
	var lines: Array[String] = []
	var has_error: bool = false
	var visible_pixel_count: int = 0

	if absolute_source_path.is_empty():
		lines.append("- Source image path could not be resolved.")
		has_error = true
		return {
			"is_valid": false,
			"visible_pixel_count": 0,
			"lines": lines,
		}

	if not FileAccess.file_exists(absolute_source_path):
		lines.append("- Source image file does not exist.")
		has_error = true
		return {
			"is_valid": false,
			"visible_pixel_count": 0,
			"lines": lines,
		}

	if image == null:
		lines.append("- Image failed to load.")
		has_error = true
		return {
			"is_valid": false,
			"visible_pixel_count": 0,
			"lines": lines,
		}

	if image.get_width() <= 0 or image.get_height() <= 0:
		lines.append("- Image dimensions are invalid.")
		has_error = true
	else:
		lines.append("- Image dimensions: %sx%s" % [image.get_width(), image.get_height()])

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				visible_pixel_count += 1

	if visible_pixel_count <= 0:
		lines.append("- Image has no visible pixels.")
		has_error = true
	else:
		lines.append("- Visible pixel count: %s" % visible_pixel_count)

	if visible_pixel_count > MAX_VISIBLE_PIXELS_WARNING:
		lines.append("- Warning: visible pixel count exceeds current recommended runtime safety cap of %s." % MAX_VISIBLE_PIXELS_WARNING)

	return {
		"is_valid": not has_error,
		"visible_pixel_count": visible_pixel_count,
		"lines": lines,
	}