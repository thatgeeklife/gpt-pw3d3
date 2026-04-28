extends Resource

@export var level_key: String = ""
@export var level_id: String = ""
@export var level_name: String = ""
@export var theme_id: String = ""
@export var preview_texture_path: String = ""
@export var baked_tres_path: String = ""
@export var baked_json_path: String = ""
@export var visible_pixel_count: int = 0
@export var palette_count: int = 0
@export var image_width: int = 0
@export var image_height: int = 0
@export var required_level_ids: Array[String] = []
@export var required_dlc_id: String = ""
@export var sort_order: int = 0

@export var is_unlocked: bool = false
@export var is_completed: bool = false
@export var unlock_status: String = "locked"
@export var unlock_reason: String = ""
@export var is_available: bool = false

var definition: Resource = null

func configure_from_manifest(data: Dictionary) -> void:
	level_key = str(data.get("level_name", ""))
	level_id = str(data.get("level_id", ""))
	level_name = str(data.get("level_name", ""))
	theme_id = str(data.get("theme_id", ""))
	preview_texture_path = str(data.get("preview_image_path", data.get("source_image_path", "")))
	baked_tres_path = str(data.get("baked_tres_path", ""))
	baked_json_path = str(data.get("baked_json_path", ""))
	visible_pixel_count = int(data.get("visible_pixel_count", 0))
	palette_count = int(data.get("palette_count", 0))
	image_width = int(data.get("image_width", 0))
	image_height = int(data.get("image_height", 0))
	required_level_ids = Array(data.get("required_level_ids", []), TYPE_STRING, "", null)
	required_dlc_id = str(data.get("required_dlc_id", ""))
	sort_order = int(data.get("sort_order", 0))

func get_display_title() -> String:
	if not level_name.is_empty():
		return level_name
	return level_key