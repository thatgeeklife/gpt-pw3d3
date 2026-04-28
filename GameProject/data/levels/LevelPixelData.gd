extends Resource

## Stores one imported non-transparent pixel from a source level image.
## This is static level-definition data and never stores runtime completion state.

@export var pixel_id: int = -1
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var source_color: Color = Color.WHITE
@export var color_key: String = ""
@export var color_code: String = ""

func configure(
	new_pixel_id: int,
	new_grid_pos: Vector2i,
	new_source_color: Color,
	new_color_key: String = "",
	new_color_code: String = ""
) -> void:
	pixel_id = new_pixel_id
	grid_pos = new_grid_pos
	source_color = new_source_color
	color_key = new_color_key
	color_code = new_color_code

func duplicate_data() -> Resource:
	var copy: Resource = load(get_script().resource_path).new()
	copy.pixel_id = pixel_id
	copy.grid_pos = grid_pos
	copy.source_color = source_color
	copy.color_key = color_key
	copy.color_code = color_code
	return copy

func to_dictionary() -> Dictionary:
	return {
		"pixel_id": pixel_id,
		"grid_x": grid_pos.x,
		"grid_y": grid_pos.y,
		"source_color": {
			"r": source_color.r,
			"g": source_color.g,
			"b": source_color.b,
			"a": source_color.a,
		},
		"color_key": color_key,
		"color_code": color_code,
	}

static func from_dictionary(data: Dictionary) -> Resource:
	var pixel: Resource = load("res://data/levels/LevelPixelData.gd").new()
	pixel.pixel_id = int(data.get("pixel_id", -1))
	pixel.grid_pos = Vector2i(
		int(data.get("grid_x", 0)),
		int(data.get("grid_y", 0))
	)
	var color_data: Dictionary = Dictionary(data.get("source_color", {}))
	pixel.source_color = Color(
		float(color_data.get("r", 1.0)),
		float(color_data.get("g", 1.0)),
		float(color_data.get("b", 1.0)),
		float(color_data.get("a", 1.0))
	)
	pixel.color_key = str(data.get("color_key", ""))
	pixel.color_code = str(data.get("color_code", ""))
	return pixel