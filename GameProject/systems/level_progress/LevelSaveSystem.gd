extends RefCounted

## Milestone 11 save/writeback system for generated-level progress.
## Responsibilities:
## - load local progress from user:// JSON
## - keep an in-memory PlayerProgressData resource
## - mark progress dirty when changes happen
## - autosave / save-if-dirty support
## - merge active session state back into local progress safely

const PLAYER_PROGRESS_SCRIPT := preload("res://systems/level_progress/PlayerProgressData.gd")

var local_progress: Resource = null
var loaded_save_path: String = ""
var _dirty: bool = false

func load_local_progress(profile_id: String = "") -> Resource:
	var save_path: String = _get_save_path(profile_id)
	loaded_save_path = save_path

	if FileAccess.file_exists(save_path):
		var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			var json_text: String = file.get_as_text()
			file.close()

			var parsed = JSON.parse_string(json_text)
			if typeof(parsed) == TYPE_DICTIONARY:
				local_progress = PLAYER_PROGRESS_SCRIPT.from_dictionary(parsed)
			else:
				local_progress = PLAYER_PROGRESS_SCRIPT.new()
		else:
			local_progress = PLAYER_PROGRESS_SCRIPT.new()
	else:
		local_progress = PLAYER_PROGRESS_SCRIPT.new()

	_ensure_default_unlocks()
	local_progress.normalize_after_load()
	_dirty = false
	return local_progress

func save_local_progress(profile_id: String = "") -> int:
	if local_progress == null:
		local_progress = PLAYER_PROGRESS_SCRIPT.new()

	var save_path: String = _get_save_path(profile_id)
	loaded_save_path = save_path

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(local_progress.to_dictionary(), "\t"))
	file.flush()
	file.close()
	_dirty = false
	return OK

func save_if_dirty(profile_id: String = "") -> int:
	if not _dirty:
		return OK
	return save_local_progress(profile_id)

func has_dirty_changes() -> bool:
	return _dirty

func mark_dirty() -> void:
	_dirty = true

func get_local_progress() -> Resource:
	if local_progress == null:
		local_progress = PLAYER_PROGRESS_SCRIPT.new()
		_ensure_default_unlocks()
	return local_progress

func mark_tile_completed(level_id: String, pixel_id: int) -> void:
	var progress: Resource = get_local_progress()
	if not progress.is_tile_completed(level_id, pixel_id):
		progress.mark_tile_completed(level_id, pixel_id)
		_dirty = true

func mark_level_complete(level_id: String) -> void:
	var progress: Resource = get_local_progress()
	if not progress.is_level_complete(level_id):
		progress.mark_level_complete(level_id)
		_dirty = true

func unlock_level(level_id: String) -> void:
	var progress: Resource = get_local_progress()
	if not progress.is_level_unlocked(level_id):
		progress.unlock_level(level_id)
		_dirty = true

func is_level_unlocked(level_id: String) -> bool:
	return get_local_progress().is_level_unlocked(level_id)

func owns_dlc(dlc_id: String) -> bool:
	return get_local_progress().owns_dlc(dlc_id)

func get_loaded_save_path() -> String:
	return loaded_save_path

func merge_session_progress(level_definition: Resource, session_state: Resource) -> void:
	if level_definition == null:
		return
	if session_state == null:
		return

	var level_id: String = str(level_definition.level_id)
	for pixel_resource in level_definition.pixels:
		if pixel_resource == null:
			continue
		var pixel_id: int = int(pixel_resource.pixel_id)
		if session_state.is_tile_completed(pixel_id):
			mark_tile_completed(level_id, pixel_id)

	if bool(session_state.is_level_complete):
		mark_level_complete(level_id)

func _get_save_path(profile_id: String = "") -> String:
	var clean_profile_id: String = profile_id.strip_edges()
	if clean_profile_id.is_empty():
		clean_profile_id = "default"
	return "user://player_progress_%s.json" % clean_profile_id

func _ensure_default_unlocks() -> void:
	if local_progress == null:
		return

	# Keep early generated content reachable while unlock rules continue to evolve.
	if not local_progress.is_level_unlocked("generated_forest_16"):
		local_progress.unlock_level("generated_forest_16")
	if not local_progress.is_level_unlocked("generated_lava_32"):
		local_progress.unlock_level("generated_lava_32")