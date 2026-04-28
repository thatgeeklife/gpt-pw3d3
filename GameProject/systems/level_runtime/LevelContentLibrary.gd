extends RefCounted

const LEVEL_IMAGE_IMPORTER_SCRIPT := preload("res://systems/level_runtime/LevelImageImporter.gd")
const LEVEL_THEME_SCRIPT := preload("res://data/levels/LevelTheme.gd")
const LEVEL_CATALOG_SERVICE_SCRIPT := preload("res://systems/level_runtime/LevelCatalogService.gd")
const MAX_SAFE_VISIBLE_PIXELS := 12000
const THEME_JSON_DIRECTORY := "res://data/levels/themes/"

var _cached_definitions: Dictionary = {}
var _catalog_service = LEVEL_CATALOG_SERVICE_SCRIPT.new()
var _cached_theme_resources: Dictionary = {}

func get_catalog_entries(player_progress: Resource = null) -> Array:
	return _catalog_service.load_catalog(player_progress)

func get_catalog_entry(level_key: String, player_progress: Resource = null) -> Resource:
	return _catalog_service.get_entry_by_level_key(level_key, player_progress)

func get_available_level_keys(player_progress: Resource = null) -> Array[String]:
	return _catalog_service.get_available_level_keys(player_progress)

func get_level_definition(level_key: String) -> Resource:
	var catalog_entry: Resource = get_catalog_entry(level_key)
	if catalog_entry != null and catalog_entry.definition != null:
		return catalog_entry.definition

	if _cached_definitions.has(level_key):
		return _cached_definitions[level_key]

	var image_path: String = _get_image_path_for_level_key(level_key)
	if image_path.is_empty():
		return null

	var definition: Resource = LEVEL_IMAGE_IMPORTER_SCRIPT.import_image_to_definition(
		image_path,
		_get_level_id_for_key(level_key),
		_get_level_name_for_key(level_key),
		_get_theme_id_for_key(level_key)
	)

	if definition != null:
		_cached_definitions[level_key] = definition

	return definition

func get_theme_for_level_key(level_key: String) -> Resource:
	var catalog_entry: Resource = get_catalog_entry(level_key)
	var theme_id: String = _get_theme_id_for_key(level_key)
	if catalog_entry != null and not str(catalog_entry.theme_id).is_empty():
		theme_id = str(catalog_entry.theme_id)

	var loaded_theme: Resource = _load_theme_from_json(theme_id)
	if loaded_theme != null:
		return loaded_theme

	var theme: Resource = LEVEL_THEME_SCRIPT.new()

	match theme_id:
		"theme_lava", "lava_theme":
			theme.configure("theme_lava", "Lava Theme", Color(0.31, 0.17, 0.11, 1.0), Color(0.25, 0.18, 0.13, 1.0), Color(0.45, 0.23, 0.16, 1.0))
		"theme_portrait", "portrait_theme":
			theme.configure("theme_portrait", "Portrait Theme", Color(0.29, 0.22, 0.18, 1.0), Color(0.24, 0.18, 0.14, 1.0), Color(0.39, 0.30, 0.23, 1.0))
		"theme_scene", "scene_theme":
			theme.configure("theme_scene", "Scene Theme", Color(0.26, 0.24, 0.18, 1.0), Color(0.20, 0.18, 0.14, 1.0), Color(0.35, 0.31, 0.24, 1.0))
		_:
			theme.configure("theme_forest", "Forest Theme", Color(0.30, 0.24, 0.17, 1.0), Color(0.25, 0.20, 0.14, 1.0), Color(0.34, 0.28, 0.19, 1.0))

	theme.tile_height = 0.25
	theme.wall_height = 5.0
	theme.wall_thickness = 0.5
	theme.tile_muting_strength = 0.0
	theme.cell_world_size = 2.0
	return theme

func get_demo_asset_paths() -> Array[String]:
	var paths: Array[String] = []
	for entry_variant in get_catalog_entries():
		var entry: Resource = entry_variant
		if entry == null:
			continue
		paths.append(str(entry.baked_tres_path))
	return paths

func is_definition_safe(definition: Resource) -> bool:
	if definition == null:
		return false
	return definition.get_pixel_count() <= MAX_SAFE_VISIBLE_PIXELS

func get_safety_warning(definition: Resource) -> String:
	if definition == null:
		return "Level definition could not be loaded."
	return "Level too dense for current runtime safety cap (%d visible tiles max)." % MAX_SAFE_VISIBLE_PIXELS

func clear_cached_fallback_definitions() -> void:
	_cached_definitions.clear()
	_cached_theme_resources.clear()

func _load_theme_from_json(theme_id: String) -> Resource:
	if theme_id.is_empty():
		return null
	if _cached_theme_resources.has(theme_id):
		return _cached_theme_resources[theme_id]

	var candidate_paths: Array[String] = [
		"%s%s.json" % [THEME_JSON_DIRECTORY, theme_id],
		"%s%s_theme.json" % [THEME_JSON_DIRECTORY, theme_id],
	]
	for candidate_path in candidate_paths:
		var absolute_path: String = ProjectSettings.globalize_path(candidate_path)
		if not FileAccess.file_exists(absolute_path):
			continue
		var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var theme: Resource = LEVEL_THEME_SCRIPT.from_dictionary(parsed)
		if theme != null:
			_cached_theme_resources[theme_id] = theme
			return theme

	return null

func _get_image_path_for_level_key(level_key: String) -> String:
	match level_key:
		"Lava":
			return "res://assets/levels/lava_icon_32.png"
		"Portrait":
			return "res://assets/levels/portrait_64.png"
		"Scene":
			return "res://assets/levels/scene_512.png"
		"Forest":
			return "res://assets/levels/forest_icon_16.png"
		_:
			return ""

func _get_level_id_for_key(level_key: String) -> String:
	var catalog_entry: Resource = get_catalog_entry(level_key)
	if catalog_entry != null and not str(catalog_entry.level_id).is_empty():
		return str(catalog_entry.level_id)
	return "generated_unknown"

func _get_level_name_for_key(level_key: String) -> String:
	var catalog_entry: Resource = get_catalog_entry(level_key)
	if catalog_entry != null and not str(catalog_entry.level_name).is_empty():
		return str(catalog_entry.level_name)
	return level_key

func _get_theme_id_for_key(level_key: String) -> String:
	var catalog_entry: Resource = get_catalog_entry(level_key)
	if catalog_entry != null and not str(catalog_entry.theme_id).is_empty():
		return str(catalog_entry.theme_id)
	return "theme_default"
