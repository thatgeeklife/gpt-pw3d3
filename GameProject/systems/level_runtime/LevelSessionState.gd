extends Resource

## Host-authoritative active generated-level session state.
## This is the shared runtime state for the currently played level.
## It is seeded from the host's personal progress when the session starts.

@export var active_level_id: String = ""
@export var active_theme_id: String = ""
@export var completed_pixel_ids: Dictionary = {}
@export var is_level_complete: bool = false

func reset() -> void:
	active_level_id = ""
	active_theme_id = ""
	completed_pixel_ids.clear()
	is_level_complete = false

func seed_from_host_progress(level_definition: Resource, theme_id: String, host_progress: Resource) -> void:
	reset()

	if level_definition == null:
		push_error("LevelSessionState: level definition was null during seed.")
		return

	active_level_id = str(level_definition.level_id)
	active_theme_id = theme_id

	if host_progress == null:
		return

	completed_pixel_ids = host_progress.get_completed_pixel_ids(active_level_id)
	is_level_complete = bool(host_progress.is_level_complete(active_level_id))

func configure_from_dictionary(data: Dictionary) -> void:
	active_level_id = str(data.get("active_level_id", ""))
	active_theme_id = str(data.get("active_theme_id", ""))
	completed_pixel_ids = _normalize_completed_pixel_ids(Dictionary(data.get("completed_pixel_ids", {})))
	is_level_complete = bool(data.get("is_level_complete", false))

func to_dictionary() -> Dictionary:
	return {
		"active_level_id": active_level_id,
		"active_theme_id": active_theme_id,
		"completed_pixel_ids": _normalize_completed_pixel_ids(completed_pixel_ids),
		"is_level_complete": is_level_complete,
	}

func is_tile_completed(pixel_id: int) -> bool:
	return bool(completed_pixel_ids.get(pixel_id, false))

func complete_tile(pixel_id: int) -> bool:
	if is_tile_completed(pixel_id):
		return false

	completed_pixel_ids[pixel_id] = true
	return true

func get_completed_tile_count() -> int:
	return completed_pixel_ids.size()

func get_completed_pixel_ids_copy() -> Dictionary:
	return _normalize_completed_pixel_ids(completed_pixel_ids)

func set_level_complete(completed: bool) -> void:
	is_level_complete = completed

func apply_to_generated_level_root(generated_root: Node) -> void:
	if generated_root == null:
		return

	var tile_root = generated_root.get_node_or_null("TileRoot")
	if tile_root == null:
		return

	for child in tile_root.get_children():
		if not child.has_method("get"):
			continue

		var pixel_id: int = int(child.get("pixel_id"))
		var completed: bool = is_tile_completed(pixel_id)
		if child.has_method("apply_runtime_state"):
			child.apply_runtime_state(completed)
		elif completed and child.has_method("set_completed"):
			child.set_completed()
		elif child.has_method("set_incomplete"):
			child.set_incomplete()

static func from_dictionary(data: Dictionary) -> Resource:
	var session_state: Resource = load("res://systems/level_runtime/LevelSessionState.gd").new()
	session_state.configure_from_dictionary(data)
	return session_state

func _normalize_completed_pixel_ids(source_dict: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key_variant in source_dict.keys():
		normalized[int(key_variant)] = bool(source_dict[key_variant])
	return normalized