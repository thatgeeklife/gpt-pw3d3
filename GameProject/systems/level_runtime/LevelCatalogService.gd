extends RefCounted

const LEVEL_CATALOG_ENTRY_SCRIPT := preload("res://systems/level_runtime/LevelCatalogEntry.gd")
const BAKED_LEVEL_ADAPTER_SCRIPT := preload("res://systems/level_runtime/BakedLevelDefinitionAdapter.gd")
const LEVEL_UNLOCK_SERVICE_SCRIPT := preload("res://systems/level_progress/LevelUnlockService.gd")

const DEFAULT_MANIFEST_REL_PATH := "../SharedLevelContent/bake_manifest.json"

var _adapter = BAKED_LEVEL_ADAPTER_SCRIPT.new()
var _unlock_service = LEVEL_UNLOCK_SERVICE_SCRIPT.new()

var _cached_manifest_mtime: int = -1
var _cached_base_entries: Array = []
var _cached_definitions_by_path: Dictionary = {}

func load_catalog(player_progress: Resource = null) -> Array:
	_ensure_catalog_cache()

	var entries: Array = []
	for base_entry_variant in _cached_base_entries:
		var base_entry: Resource = base_entry_variant
		if base_entry == null:
			continue

		var entry: Resource = LEVEL_CATALOG_ENTRY_SCRIPT.new()
		entry.level_key = str(base_entry.level_key)
		entry.level_id = str(base_entry.level_id)
		entry.level_name = str(base_entry.level_name)
		entry.theme_id = str(base_entry.theme_id)
		entry.preview_texture_path = str(base_entry.preview_texture_path)
		entry.baked_tres_path = str(base_entry.baked_tres_path)
		entry.baked_json_path = str(base_entry.baked_json_path)
		entry.visible_pixel_count = int(base_entry.visible_pixel_count)
		entry.palette_count = int(base_entry.palette_count)
		entry.image_width = int(base_entry.image_width)
		entry.image_height = int(base_entry.image_height)
		entry.required_level_ids = Array(base_entry.required_level_ids, TYPE_STRING, "", null)
		entry.required_dlc_id = str(base_entry.required_dlc_id)
		entry.sort_order = int(base_entry.sort_order)
		entry.definition = base_entry.definition
		entry.is_available = base_entry.definition != null

		if player_progress != null and entry.definition != null:
			var unlock_status: Dictionary = _unlock_service.get_unlock_status(entry.definition, player_progress)
			entry.is_unlocked = bool(unlock_status.get("is_unlocked", false))
			entry.unlock_status = str(unlock_status.get("status", "locked"))
			entry.unlock_reason = str(unlock_status.get("reason", ""))
			entry.is_completed = player_progress.is_level_complete(str(entry.level_id))
		else:
			entry.is_unlocked = entry.definition != null
			if entry.definition != null:
				entry.unlock_status = "unlocked"
				entry.unlock_reason = ""
			else:
				entry.unlock_status = "invalid_definition"
				entry.unlock_reason = "Baked definition could not be loaded."
			entry.is_completed = false

		entries.append(entry)

	return entries

func get_entry_by_level_key(level_key: String, player_progress: Resource = null) -> Resource:
	for entry_variant in load_catalog(player_progress):
		var entry: Resource = entry_variant
		if entry == null:
			continue
		if str(entry.level_key) == level_key or str(entry.level_name) == level_key or str(entry.level_id) == level_key:
			return entry
	return null

func get_available_level_keys(player_progress: Resource = null) -> Array[String]:
	var keys: Array[String] = []
	for entry_variant in load_catalog(player_progress):
		var entry: Resource = entry_variant
		if entry == null:
			continue
		keys.append(str(entry.level_key))
	return keys

func clear_cache() -> void:
	_cached_manifest_mtime = -1
	_cached_base_entries.clear()
	_cached_definitions_by_path.clear()

func _ensure_catalog_cache() -> void:
	var absolute_manifest_path: String = _resolve_path(DEFAULT_MANIFEST_REL_PATH)
	var current_manifest_mtime: int = 0
	if FileAccess.file_exists(absolute_manifest_path):
		current_manifest_mtime = int(FileAccess.get_modified_time(absolute_manifest_path))

	if current_manifest_mtime == _cached_manifest_mtime and not _cached_base_entries.is_empty():
		return

	_cached_manifest_mtime = current_manifest_mtime
	_cached_base_entries.clear()
	_cached_definitions_by_path.clear()

	var manifest: Dictionary = _load_manifest()
	var manifest_levels: Array = Array(manifest.get("levels", []))

	for index in range(manifest_levels.size()):
		var manifest_entry = manifest_levels[index]
		if typeof(manifest_entry) != TYPE_DICTIONARY:
			continue

		var entry: Resource = LEVEL_CATALOG_ENTRY_SCRIPT.new()
		entry.configure_from_manifest(manifest_entry)
		if entry.level_key.is_empty():
			entry.level_key = entry.level_id

		entry.definition = _load_definition_for_manifest_entry(manifest_entry)
		entry.is_available = entry.definition != null
		if entry.definition != null:
			entry.visible_pixel_count = entry.definition.get_pixel_count()
			entry.required_level_ids = Array(entry.definition.required_level_ids, TYPE_STRING, "", null)
			entry.required_dlc_id = str(entry.definition.required_dlc_id)

		if entry.sort_order == 0:
			entry.sort_order = index + 1

		_cached_base_entries.append(entry)

	_cached_base_entries.sort_custom(func(a, b):
		if int(a.sort_order) != int(b.sort_order):
			return int(a.sort_order) < int(b.sort_order)
		return str(a.get_display_title()) < str(b.get_display_title())
	)

func _load_manifest() -> Dictionary:
	var absolute_manifest_path: String = _resolve_path(DEFAULT_MANIFEST_REL_PATH)
	if not FileAccess.file_exists(absolute_manifest_path):
		return {"levels": []}

	var file: FileAccess = FileAccess.open(absolute_manifest_path, FileAccess.READ)
	if file == null:
		return {"levels": []}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"levels": []}
	return parsed

func _load_definition_for_manifest_entry(manifest_entry: Dictionary) -> Resource:
	var baked_tres_path: String = str(manifest_entry.get("baked_tres_path", ""))
	if not baked_tres_path.is_empty():
		var abs_tres: String = _resolve_path(baked_tres_path)
		var definition_from_tres: Resource = _load_definition_with_cache(abs_tres)
		if definition_from_tres != null:
			return definition_from_tres

	var baked_json_path: String = str(manifest_entry.get("baked_json_path", ""))
	if not baked_json_path.is_empty():
		var abs_json: String = _resolve_path(baked_json_path)
		var definition_from_json: Resource = _load_definition_with_cache(abs_json)
		if definition_from_json != null:
			return definition_from_json

	return null

func _load_definition_with_cache(absolute_path: String) -> Resource:
	if absolute_path.is_empty():
		return null
	if not FileAccess.file_exists(absolute_path):
		return null

	var modified_time: int = int(FileAccess.get_modified_time(absolute_path))
	var cached: Dictionary = Dictionary(_cached_definitions_by_path.get(absolute_path, {}))
	if not cached.is_empty() and int(cached.get("modified_time", -1)) == modified_time:
		return cached.get("definition", null)

	var definition: Resource = _adapter.load_baked_text_definition_as_legacy_definition(absolute_path)
	_cached_definitions_by_path[absolute_path] = {
		"modified_time": modified_time,
		"definition": definition,
	}
	return definition

func _resolve_path(path_value: String) -> String:
	if path_value.begins_with("res://") or path_value.begins_with("user://"):
		return ProjectSettings.globalize_path(path_value)
	if path_value.begins_with("/") or path_value.contains(":/") or path_value.contains(":\\"):
		return path_value
	var project_root: String = ProjectSettings.globalize_path("res://")
	return project_root.path_join(path_value).simplify_path()
