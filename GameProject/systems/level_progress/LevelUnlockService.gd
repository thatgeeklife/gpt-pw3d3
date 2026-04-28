extends RefCounted

func get_unlock_status(level_definition: Resource, player_progress: Resource) -> Dictionary:
	var result: Dictionary = {
		"is_unlocked": false,
		"status": "invalid_definition",
		"reason": "Level definition is missing.",
		"missing_required_level_ids": [],
	}

	if level_definition == null:
		return result
	if player_progress == null:
		result["status"] = "missing_progress"
		result["reason"] = "Player progress is unavailable."
		return result

	var missing_required_level_ids: Array[String] = []
	for required_level_id_variant in level_definition.required_level_ids:
		var required_level_id: String = str(required_level_id_variant)
		if not player_progress.is_level_complete(required_level_id):
			missing_required_level_ids.append(required_level_id)

	if not missing_required_level_ids.is_empty():
		result["status"] = "locked_prerequisite"
		result["reason"] = "Complete first: %s" % ", ".join(missing_required_level_ids)
		result["missing_required_level_ids"] = missing_required_level_ids
		return result

	var required_dlc_id: String = str(level_definition.required_dlc_id)
	if not required_dlc_id.is_empty() and not player_progress.owns_dlc(required_dlc_id):
		result["status"] = "locked_dlc"
		result["reason"] = "Requires DLC: %s" % required_dlc_id
		return result

	result["is_unlocked"] = true
	result["status"] = "unlocked"
	result["reason"] = ""
	return result

func are_prerequisites_met(level_definition: Resource, player_progress: Resource) -> bool:
	return str(get_unlock_status(level_definition, player_progress).get("status", "")) != "locked_prerequisite"

func is_dlc_requirement_met(level_definition: Resource, player_progress: Resource) -> bool:
	return str(get_unlock_status(level_definition, player_progress).get("status", "")) != "locked_dlc"

func is_level_unlocked(level_definition: Resource, player_progress: Resource) -> bool:
	return bool(get_unlock_status(level_definition, player_progress).get("is_unlocked", false))

func can_receive_progress_for_level(level_definition: Resource, player_progress: Resource) -> bool:
	return is_level_unlocked(level_definition, player_progress)

func refresh_unlocks_for_player(player_progress: Resource, level_catalog: Resource) -> void:
	if player_progress == null or level_catalog == null:
		return

	if level_catalog.has_method("load_catalog"):
		for entry_variant in level_catalog.load_catalog(player_progress):
			var entry: Resource = entry_variant
			if entry == null or entry.definition == null:
				continue
			if is_level_unlocked(entry.definition, player_progress):
				player_progress.unlock_level(str(entry.level_id))
		return

	for level_definition in level_catalog.levels:
		if level_definition == null:
			continue
		if is_level_unlocked(level_definition, player_progress):
			player_progress.unlock_level(str(level_definition.level_id))