extends RefCounted

const DEFAULT_EXPORT_DIR := "../GameProject/data/levels/themes"

func load_theme_json(absolute_path: String) -> Dictionary:
	if absolute_path.is_empty():
		return {"ok": false, "error": "Path was empty."}
	if not FileAccess.file_exists(absolute_path):
		return {"ok": false, "error": "Theme file does not exist."}

	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Failed opening theme file."}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Theme JSON did not parse to a dictionary."}

	return {"ok": true, "data": parsed}

func save_theme_json(absolute_path: String, payload: Dictionary) -> Dictionary:
	if absolute_path.is_empty():
		return {"ok": false, "error": "Save path was empty."}

	var output_dir: String = absolute_path.get_base_dir()
	if not output_dir.is_empty():
		var make_error: Error = DirAccess.make_dir_recursive_absolute(output_dir)
		if make_error != OK and make_error != ERR_ALREADY_EXISTS:
			return {"ok": false, "error": "Failed creating output directory."}

	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Failed opening save file."}

	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	return {"ok": true}

func get_default_export_absolute_path(project_root_absolute: String, theme_id: String) -> String:
	var safe_theme_id: String = theme_id.strip_edges()
	if safe_theme_id.is_empty():
		safe_theme_id = "new_theme"
	return project_root_absolute.path_join("%s/%s_theme.json" % [DEFAULT_EXPORT_DIR, safe_theme_id]).simplify_path()

func to_preferred_display_path(project_root_absolute: String, absolute_path: String) -> String:
	var clean_absolute: String = absolute_path.simplify_path()
	var level_baker_root: String = project_root_absolute.simplify_path()
	var game_project_root: String = level_baker_root.path_join("../GameProject").simplify_path()

	if clean_absolute.begins_with(game_project_root):
		var suffix: String = clean_absolute.trim_prefix(game_project_root).trim_prefix("/")
		return "../GameProject/%s" % suffix

	if clean_absolute.begins_with(level_baker_root):
		var suffix2: String = clean_absolute.trim_prefix(level_baker_root).trim_prefix("/")
		return suffix2

	return clean_absolute

func resolve_path(project_root_absolute: String, user_path: String) -> String:
	if user_path.begins_with("user://"):
		return ProjectSettings.globalize_path(user_path)
	if user_path.begins_with("res://"):
		var suffix: String = user_path.trim_prefix("res://").trim_prefix("/")
		return project_root_absolute.path_join("../GameProject/%s" % suffix).simplify_path()
	if user_path.begins_with("/") or user_path.contains(":/") or user_path.contains(":\\"):
		return user_path
	return project_root_absolute.path_join(user_path).simplify_path()

func absolute_game_scene_path_to_res_path(project_root_absolute: String, absolute_path: String) -> String:
	var clean_absolute: String = absolute_path.simplify_path()
	var game_project_root: String = project_root_absolute.path_join("../GameProject").simplify_path()
	if clean_absolute.begins_with(game_project_root):
		var suffix: String = clean_absolute.trim_prefix(game_project_root).trim_prefix("/")
		return "res://%s" % suffix
	return clean_absolute
