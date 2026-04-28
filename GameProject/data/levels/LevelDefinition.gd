extends Resource

## Stores the static imported layout for one generated level.
## Runtime completion state belongs in player progress or the active session state.

@export var level_id: String = ""
@export var level_name: String = ""
@export var source_width: int = 0
@export var source_height: int = 0
@export var default_theme_id: String = ""
@export var required_level_ids: Array[String] = []
@export var required_dlc_id: String = ""
@export var pixels: Array[Resource] = []

func configure(
	new_level_id: String,
	new_level_name: String,
	new_source_width: int,
	new_source_height: int,
	new_default_theme_id: String,
	new_required_level_ids: Array[String] = [],
	new_required_dlc_id: String = ""
) -> void:
	level_id = new_level_id
	level_name = new_level_name
	source_width = new_source_width
	source_height = new_source_height
	default_theme_id = new_default_theme_id
	required_level_ids = new_required_level_ids.duplicate()
	required_dlc_id = new_required_dlc_id

func add_pixel(pixel_resource: Resource) -> void:
	if pixel_resource == null:
		return
	pixels.append(pixel_resource)

func clear_pixels() -> void:
	pixels.clear()

func get_pixel_count() -> int:
	return pixels.size()

func get_pixel_by_id(pixel_id: int) -> Resource:
	for pixel_resource in pixels:
		if pixel_resource == null:
			continue
		if int(pixel_resource.pixel_id) == pixel_id:
			return pixel_resource
	return null

func has_pixel_id(pixel_id: int) -> bool:
	return get_pixel_by_id(pixel_id) != null

func get_sorted_pixel_ids() -> Array[int]:
	var ids: Array[int] = []
	for pixel_resource in pixels:
		if pixel_resource == null:
			continue
		ids.append(int(pixel_resource.pixel_id))
	ids.sort()
	return ids

func get_color_palette_entries() -> Array:
	var entries: Array = []
	var seen: Dictionary = {}
	for pixel_resource in pixels:
		if pixel_resource == null:
			continue
		var key: String = str(pixel_resource.color_key)
		if seen.has(key):
			continue
		seen[key] = true
		entries.append({
			"color_key": key,
			"color_code": str(pixel_resource.color_code),
			"source_color": pixel_resource.source_color,
		})
	return entries

func to_dictionary() -> Dictionary:
	var pixel_dicts: Array = []
	for pixel_resource in pixels:
		if pixel_resource == null:
			continue
		if pixel_resource.has_method("to_dictionary"):
			pixel_dicts.append(pixel_resource.to_dictionary())

	return {
		"level_id": level_id,
		"level_name": level_name,
		"source_width": source_width,
		"source_height": source_height,
		"default_theme_id": default_theme_id,
		"required_level_ids": required_level_ids.duplicate(),
		"required_dlc_id": required_dlc_id,
		"pixels": pixel_dicts,
	}

static func from_dictionary(data: Dictionary) -> Resource:
	var definition: Resource = load("res://data/levels/LevelDefinition.gd").new()
	definition.level_id = str(data.get("level_id", ""))
	definition.level_name = str(data.get("level_name", ""))
	definition.source_width = int(data.get("source_width", 0))
	definition.source_height = int(data.get("source_height", 0))
	definition.default_theme_id = str(data.get("default_theme_id", ""))
	definition.required_level_ids = Array(data.get("required_level_ids", []), TYPE_STRING, "", null)
	definition.required_dlc_id = str(data.get("required_dlc_id", ""))

	var pixel_array: Array = Array(data.get("pixels", []))
	for pixel_data in pixel_array:
		if typeof(pixel_data) != TYPE_DICTIONARY:
			continue
		var pixel_resource: Resource = load("res://data/levels/LevelPixelData.gd").from_dictionary(pixel_data)
		definition.pixels.append(pixel_resource)

	return definition