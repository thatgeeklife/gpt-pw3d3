extends Resource

## Persistent per-player progress data.
## This is personal save data, not the active host-authoritative session state.

@export var unlocked_level_ids: Dictionary = {}
@export var owned_dlc_ids: Dictionary = {}
@export var levels_progress: Dictionary = {}

func ensure_level_progress(level_id: String) -> Dictionary:
	if not levels_progress.has(level_id):
		levels_progress[level_id] = {
			"completed_pixel_ids": {},
			"is_level_complete": false,
		}
	return levels_progress[level_id]

func get_completed_pixel_ids(level_id: String) -> Dictionary:
	if not levels_progress.has(level_id):
		return {}
	var level_progress: Dictionary = levels_progress[level_id]
	return _normalize_completed_pixel_ids(Dictionary(level_progress.get("completed_pixel_ids", {})))

func is_tile_completed(level_id: String, pixel_id: int) -> bool:
	var completed_pixel_ids: Dictionary = get_completed_pixel_ids(level_id)
	return bool(completed_pixel_ids.get(pixel_id, false))

func mark_tile_completed(level_id: String, pixel_id: int) -> void:
	var level_progress: Dictionary = ensure_level_progress(level_id)
	var completed_pixel_ids: Dictionary = _normalize_completed_pixel_ids(Dictionary(level_progress.get("completed_pixel_ids", {})))
	completed_pixel_ids[pixel_id] = true
	level_progress["completed_pixel_ids"] = completed_pixel_ids
	levels_progress[level_id] = level_progress

func get_completed_tile_count(level_id: String) -> int:
	return get_completed_pixel_ids(level_id).size()

func is_level_complete(level_id: String) -> bool:
	if not levels_progress.has(level_id):
		return false
	var level_progress: Dictionary = levels_progress[level_id]
	return bool(level_progress.get("is_level_complete", false))

func mark_level_complete(level_id: String) -> void:
	var level_progress: Dictionary = ensure_level_progress(level_id)
	level_progress["is_level_complete"] = true
	levels_progress[level_id] = level_progress

func unlock_level(level_id: String) -> void:
	unlocked_level_ids[level_id] = true

func is_level_unlocked(level_id: String) -> bool:
	return bool(unlocked_level_ids.get(level_id, false))

func set_dlc_owned(dlc_id: String, is_owned: bool) -> void:
	if is_owned:
		owned_dlc_ids[dlc_id] = true
	else:
		owned_dlc_ids.erase(dlc_id)

func owns_dlc(dlc_id: String) -> bool:
	if dlc_id.is_empty():
		return true
	return bool(owned_dlc_ids.get(dlc_id, false))

func normalize_after_load() -> void:
	var normalized_levels: Dictionary = {}
	for level_id_variant in levels_progress.keys():
		var level_id: String = str(level_id_variant)
		var original_level_progress: Dictionary = Dictionary(levels_progress[level_id_variant])
		var normalized_level_progress: Dictionary = {
			"completed_pixel_ids": _normalize_completed_pixel_ids(Dictionary(original_level_progress.get("completed_pixel_ids", {}))),
			"is_level_complete": bool(original_level_progress.get("is_level_complete", false)),
		}
		normalized_levels[level_id] = normalized_level_progress
	levels_progress = normalized_levels

func to_dictionary() -> Dictionary:
	var normalized_levels: Dictionary = {}
	for level_id_variant in levels_progress.keys():
		var level_id: String = str(level_id_variant)
		var level_progress: Dictionary = Dictionary(levels_progress[level_id_variant])
		normalized_levels[level_id] = {
			"completed_pixel_ids": _normalize_completed_pixel_ids(Dictionary(level_progress.get("completed_pixel_ids", {}))),
			"is_level_complete": bool(level_progress.get("is_level_complete", false)),
		}

	return {
		"unlocked_level_ids": unlocked_level_ids.duplicate(true),
		"owned_dlc_ids": owned_dlc_ids.duplicate(true),
		"levels_progress": normalized_levels,
	}

static func from_dictionary(data: Dictionary) -> Resource:
	var progress: Resource = load("res://systems/level_progress/PlayerProgressData.gd").new()
	progress.unlocked_level_ids = Dictionary(data.get("unlocked_level_ids", {})).duplicate(true)
	progress.owned_dlc_ids = Dictionary(data.get("owned_dlc_ids", {})).duplicate(true)
	progress.levels_progress = Dictionary(data.get("levels_progress", {})).duplicate(true)
	progress.normalize_after_load()
	return progress

func _normalize_completed_pixel_ids(source_dict: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key_variant in source_dict.keys():
		var pixel_id: int = int(key_variant)
		normalized[pixel_id] = bool(source_dict[key_variant])
	return normalized