extends RefCounted

const GENERATED_BY_NOTE := "M24.6.1 ModelWrapperBuilder"
const GENERATED_VERSION := "M24.6.1"
const MANAGED_IMPORT_ROOT_RES := "res://assets/theme_imports"
const SUPPORTED_MODEL_EXTENSIONS: Array[String] = ["gltf", "glb"]
const SUPPORTED_SCENE_EXTENSIONS: Array[String] = ["tscn"]

func prepare_selected_theme_piece(level_baker_root_absolute: String, selected_absolute_path: String, scene_field_key: String = "") -> Dictionary:
	var clean_selected_path: String = _normalize_selected_path(level_baker_root_absolute, selected_absolute_path)
	if clean_selected_path.is_empty():
		return _fail("Selected path was empty.")
	if not FileAccess.file_exists(clean_selected_path):
		return _fail("Selected file does not exist: %s" % clean_selected_path)

	var extension: String = clean_selected_path.get_extension().to_lower()
	if extension in SUPPORTED_SCENE_EXTENSIONS:
		var scene_res_path: String = _absolute_game_path_to_res_path(level_baker_root_absolute, clean_selected_path)
		if not scene_res_path.begins_with("res://"):
			return _fail("TSCN files must be inside GameProject so they can be exported and loaded at runtime. External .gltf/.glb files can be imported automatically, but external .tscn dependency copying is not supported yet.")
		return {
			"ok": true,
			"assigned_path": scene_res_path,
			"wrapper_created": false,
			"wrapper_reused": false,
			"source_path": clean_selected_path,
			"wrapper_path": clean_selected_path,
			"message": "Using selected .tscn directly.",
		}

	if extension in SUPPORTED_MODEL_EXTENSIONS:
		return _prepare_model_wrapper(level_baker_root_absolute, clean_selected_path, scene_field_key)

	return _fail("Unsupported theme piece file type: .%s. Use .tscn, .gltf, or .glb." % extension)

func is_supported_theme_piece_path(path_value: String) -> bool:
	var extension: String = path_value.get_extension().to_lower()
	return extension in SUPPORTED_SCENE_EXTENSIONS or extension in SUPPORTED_MODEL_EXTENSIONS

func game_res_file_exists(level_baker_root_absolute: String, res_path: String) -> bool:
	if not res_path.begins_with("res://"):
		return FileAccess.file_exists(_normalize_selected_path(level_baker_root_absolute, res_path))
	return _absolute_file_exists(_res_path_to_game_absolute_path(level_baker_root_absolute, res_path))

func repair_missing_wrapper_scene_path(level_baker_root_absolute: String, wrapper_res_path: String, scene_field_key: String = "") -> Dictionary:
	var clean_wrapper_res_path: String = wrapper_res_path.strip_edges()
	if clean_wrapper_res_path.is_empty():
		return _no_repair("No wrapper path assigned.")
	if not clean_wrapper_res_path.begins_with("res://"):
		return _no_repair("Only GameProject res:// wrapper paths can be repaired automatically.")
	if clean_wrapper_res_path.get_extension().to_lower() != "tscn":
		return _no_repair("Only .tscn wrapper paths can be repaired automatically.")
	if not clean_wrapper_res_path.get_file().get_basename().ends_with("_wrapper"):
		return _no_repair("Assigned scene is not a generated wrapper scene path.")

	var wrapper_absolute_path: String = _res_path_to_game_absolute_path(level_baker_root_absolute, clean_wrapper_res_path)
	if _absolute_file_exists(wrapper_absolute_path):
		return _no_repair("Wrapper scene already exists.")

	var misplaced_copy_result: Dictionary = _copy_misplaced_generated_assets_to_game_project(level_baker_root_absolute, clean_wrapper_res_path)
	if bool(misplaced_copy_result.get("ok", false)) and bool(misplaced_copy_result.get("repaired", false)):
		return misplaced_copy_result

	var model_absolute_path: String = _find_model_for_missing_wrapper(wrapper_absolute_path)
	if model_absolute_path.is_empty():
		model_absolute_path = _find_model_for_missing_wrapper_in_managed_imports(level_baker_root_absolute, clean_wrapper_res_path, scene_field_key)
	if model_absolute_path.is_empty():
		return _no_repair("No matching .glb or .gltf was found for missing wrapper: %s. Browse-select the original model again so it can be copied and wrapped." % clean_wrapper_res_path)

	var write_result: Dictionary = _write_wrapper_scene_for_model(level_baker_root_absolute, model_absolute_path, wrapper_absolute_path, model_absolute_path, model_absolute_path)
	if not bool(write_result.get("ok", false)):
		return write_result

	return {
		"ok": true,
		"repaired": true,
		"wrapper_res_path": clean_wrapper_res_path,
		"wrapper_path": wrapper_absolute_path,
		"source_res_path": str(write_result.get("source_res_path", "")),
		"source_path": model_absolute_path,
		"message": "Repaired missing wrapper scene: %s" % clean_wrapper_res_path,
	}

func rebuild_wrapper_for_scene_path(level_baker_root_absolute: String, assigned_scene_path: String, scene_field_key: String = "") -> Dictionary:
	var clean_scene_path: String = assigned_scene_path.strip_edges()
	if clean_scene_path.is_empty():
		return _fail("No scene path is assigned for this slot.")
	if clean_scene_path.get_extension().to_lower() != "tscn":
		return _fail("Rebuild Wrapper only works on generated wrapper .tscn paths. Browse-select the .gltf/.glb again for raw model paths.")
	if not clean_scene_path.begins_with("res://"):
		return _fail("Only GameProject res:// wrapper scenes can be rebuilt automatically.")
	if not clean_scene_path.get_file().get_basename().ends_with("_wrapper"):
		return _fail("This scene does not look like a generated wrapper. Direct .tscn scenes are left unchanged: %s" % clean_scene_path)

	var wrapper_absolute_path: String = _res_path_to_game_absolute_path(level_baker_root_absolute, clean_scene_path)
	var wrapper_text: String = _read_text(wrapper_absolute_path)
	var model_res_path: String = ""
	if not wrapper_text.is_empty():
		model_res_path = _extract_wrapper_model_res_path(wrapper_text)

	var model_absolute_path: String = ""
	if not model_res_path.is_empty():
		model_absolute_path = _res_path_to_game_absolute_path(level_baker_root_absolute, model_res_path)
		if not FileAccess.file_exists(model_absolute_path):
			model_absolute_path = ""
	if model_absolute_path.is_empty():
		model_absolute_path = _find_model_for_missing_wrapper(wrapper_absolute_path)
	if model_absolute_path.is_empty():
		model_absolute_path = _find_model_for_missing_wrapper_in_managed_imports(level_baker_root_absolute, clean_scene_path, scene_field_key)
	if model_absolute_path.is_empty():
		return _fail("Could not find the .gltf/.glb source model for wrapper: %s" % clean_scene_path)

	var write_result: Dictionary = _write_wrapper_scene_for_model(level_baker_root_absolute, model_absolute_path, wrapper_absolute_path, model_absolute_path, model_absolute_path)
	if not bool(write_result.get("ok", false)):
		return write_result

	return {
		"ok": true,
		"assigned_path": clean_scene_path,
		"wrapper_path": wrapper_absolute_path,
		"source_res_path": str(write_result.get("source_res_path", "")),
		"message": "Rebuilt wrapper scene for %s: %s" % [scene_field_key, clean_scene_path],
	}

func inspect_scene_path(level_baker_root_absolute: String, field_name: String, stored_path: String) -> Dictionary:
	var clean_path: String = stored_path.strip_edges()
	var notes: Array[String] = []
	var result: Dictionary = {
		"field": field_name,
		"stored_path": clean_path,
		"absolute_path": "",
		"status": "UNASSIGNED",
		"file_exists": false,
		"is_wrapper": false,
		"wrapper_source_res_path": "",
		"wrapper_source_absolute_path": "",
		"wrapper_source_exists": false,
		"root_type": "",
		"node_count": 0,
		"mesh_marker": false,
		"model_instance_marker": false,
		"notes": notes,
	}

	if clean_path.is_empty():
		notes.append("No authored scene assigned; runtime fallback will be used.")
		return result

	if clean_path.get_extension().to_lower() != "tscn":
		result["status"] = "FAIL"
		notes.append("Stored path is not a .tscn. Use Browse to wrap .gltf/.glb models before saving/exporting.")
		return result

	var absolute_path: String = _resolve_scene_path(level_baker_root_absolute, clean_path)
	result["absolute_path"] = absolute_path
	if not _absolute_file_exists(absolute_path):
		result["status"] = "FAIL"
		notes.append("Scene file is missing at the resolved GameProject path: %s" % absolute_path)
		return result

	result["file_exists"] = true
	var file_text: String = _read_text(absolute_path)
	if file_text.is_empty():
		result["status"] = "FAIL"
		notes.append("Scene file exists but could not be read or is empty.")
		return result

	var root_type: String = _extract_root_node_type(file_text)
	var wrapper_source_res_path: String = _extract_wrapper_model_res_path(file_text)
	var node_count: int = _count_occurrences(file_text, "[node ")
	var mesh_marker: bool = file_text.contains("MeshInstance3D")
	var model_instance_marker: bool = file_text.contains("instance=ExtResource")
	var is_generated_wrapper: bool = clean_path.get_file().get_basename().ends_with("_wrapper") or file_text.contains("metadata/generated_by") or not wrapper_source_res_path.is_empty()

	result["root_type"] = root_type
	result["node_count"] = node_count
	result["mesh_marker"] = mesh_marker
	result["model_instance_marker"] = model_instance_marker
	result["is_wrapper"] = is_generated_wrapper
	result["wrapper_source_res_path"] = wrapper_source_res_path

	if root_type.is_empty():
		result["status"] = "FAIL"
		notes.append("Scene does not contain a root [node] entry.")
	elif not root_type.ends_with("3D"):
		result["status"] = "FAIL"
		notes.append("Root node is not a 3D node: %s" % root_type)

	if is_generated_wrapper:
		if wrapper_source_res_path.is_empty():
			result["status"] = "WARN"
			notes.append("Generated wrapper metadata/source path is missing. Rebuild this wrapper.")
		else:
			var source_absolute_path: String = _res_path_to_game_absolute_path(level_baker_root_absolute, wrapper_source_res_path)
			var source_exists: bool = _absolute_file_exists(source_absolute_path)
			result["wrapper_source_absolute_path"] = source_absolute_path
			result["wrapper_source_exists"] = source_exists
			if not source_exists:
				result["status"] = "FAIL"
				notes.append("Wrapper source model is missing: %s -> %s" % [wrapper_source_res_path, source_absolute_path])
			elif str(result["status"]) == "UNASSIGNED":
				result["status"] = "OK"
	else:
		if not mesh_marker and not model_instance_marker:
			result["status"] = "WARN"
			notes.append("Direct scene has no obvious mesh/model marker. Confirm it renders correctly.")
		elif str(result["status"]) == "UNASSIGNED":
			result["status"] = "OK"

	if int(result["node_count"]) <= 0:
		result["status"] = "FAIL"
		notes.append("Scene node count is zero.")

	if str(result["status"]) == "UNASSIGNED":
		result["status"] = "OK"
	if notes.is_empty():
		notes.append("Scene path, wrapper, and source model look aligned.")

	return result

func _normalize_selected_path(level_baker_root_absolute: String, selected_path: String) -> String:
	var clean_path: String = selected_path.strip_edges().replace("\\", "/").simplify_path()
	if clean_path.begins_with("res://"):
		var game_absolute_path: String = _res_path_to_game_absolute_path(level_baker_root_absolute, clean_path)
		if FileAccess.file_exists(game_absolute_path):
			return game_absolute_path
		var level_baker_absolute_path: String = level_baker_root_absolute.path_join(clean_path.trim_prefix("res://").trim_prefix("/")).simplify_path()
		if FileAccess.file_exists(level_baker_absolute_path):
			return level_baker_absolute_path
	return clean_path

func _find_model_for_missing_wrapper(wrapper_absolute_path: String) -> String:
	var wrapper_base_name: String = wrapper_absolute_path.get_file().get_basename()
	if not wrapper_base_name.ends_with("_wrapper"):
		return ""
	var model_base_name: String = wrapper_base_name.trim_suffix("_wrapper")
	var base_dir: String = wrapper_absolute_path.get_base_dir()
	for extension in SUPPORTED_MODEL_EXTENSIONS:
		var candidate: String = base_dir.path_join("%s.%s" % [model_base_name, extension]).simplify_path()
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

func _find_model_for_missing_wrapper_in_managed_imports(level_baker_root_absolute: String, wrapper_res_path: String, scene_field_key: String) -> String:
	var wrapper_base_name: String = wrapper_res_path.get_file().get_basename()
	if not wrapper_base_name.ends_with("_wrapper"):
		return ""
	var model_base_name: String = wrapper_base_name.trim_suffix("_wrapper")
	var buckets: Array[String] = []
	var preferred_bucket: String = _bucket_for_scene_field(scene_field_key)
	if not preferred_bucket.is_empty():
		buckets.append(preferred_bucket)
	for fallback_bucket in ["walls", "floors", "props"]:
		if not buckets.has(fallback_bucket):
			buckets.append(fallback_bucket)

	for bucket in buckets:
		var bucket_dir: String = _res_path_to_game_absolute_path(level_baker_root_absolute, MANAGED_IMPORT_ROOT_RES.path_join(bucket))
		for extension in SUPPORTED_MODEL_EXTENSIONS:
			var exact_candidate: String = bucket_dir.path_join("%s.%s" % [model_base_name, extension]).simplify_path()
			if FileAccess.file_exists(exact_candidate):
				return exact_candidate
	return ""

func _copy_misplaced_generated_assets_to_game_project(level_baker_root_absolute: String, wrapper_res_path: String) -> Dictionary:
	var suffix: String = wrapper_res_path.trim_prefix("res://").trim_prefix("/")
	var level_baker_wrapper_absolute: String = level_baker_root_absolute.path_join(suffix).simplify_path()
	var game_wrapper_absolute: String = _res_path_to_game_absolute_path(level_baker_root_absolute, wrapper_res_path)
	if not FileAccess.file_exists(level_baker_wrapper_absolute):
		return _no_repair("No misplaced LevelBaker wrapper copy found.")

	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(game_wrapper_absolute.get_base_dir())
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		return _fail("Failed creating GameProject wrapper directory: %s" % game_wrapper_absolute.get_base_dir())

	var copy_error: Error = _copy_file_bytes(level_baker_wrapper_absolute, game_wrapper_absolute)
	if copy_error != OK:
		return _fail("Failed copying misplaced wrapper into GameProject: %s" % wrapper_res_path)

	var model_base_name: String = game_wrapper_absolute.get_file().get_basename().trim_suffix("_wrapper")
	for extension in SUPPORTED_MODEL_EXTENSIONS:
		var level_baker_model_absolute: String = level_baker_wrapper_absolute.get_base_dir().path_join("%s.%s" % [model_base_name, extension]).simplify_path()
		var game_model_absolute: String = game_wrapper_absolute.get_base_dir().path_join("%s.%s" % [model_base_name, extension]).simplify_path()
		if FileAccess.file_exists(level_baker_model_absolute) and not FileAccess.file_exists(game_model_absolute):
			_copy_file_bytes(level_baker_model_absolute, game_model_absolute)

	if not _absolute_file_exists(game_wrapper_absolute):
		return _fail("Copied misplaced wrapper, but GameProject copy was still not found: %s" % wrapper_res_path)

	return {
		"ok": true,
		"repaired": true,
		"wrapper_res_path": wrapper_res_path,
		"wrapper_path": game_wrapper_absolute,
		"message": "Moved misplaced generated wrapper into GameProject: %s" % wrapper_res_path,
	}

func _prepare_model_wrapper(level_baker_root_absolute: String, selected_model_absolute_path: String, scene_field_key: String) -> Dictionary:
	var runtime_model_absolute_path: String = selected_model_absolute_path
	var original_source_path: String = selected_model_absolute_path
	var imported_external_model: bool = false
	var dependency_notes: Array[String] = []
	var import_message: String = ""

	if not _is_inside_game_project(level_baker_root_absolute, selected_model_absolute_path):
		var import_result: Dictionary = _copy_external_model_to_game_project(level_baker_root_absolute, selected_model_absolute_path, scene_field_key)
		if not bool(import_result.get("ok", false)):
			return import_result
		runtime_model_absolute_path = str(import_result.get("imported_absolute_path", selected_model_absolute_path))
		imported_external_model = true
		dependency_notes = Array(import_result.get("dependency_notes", []))
		import_message = str(import_result.get("message", "Imported external model."))

	var model_res_path: String = _absolute_game_path_to_res_path(level_baker_root_absolute, runtime_model_absolute_path)
	if not model_res_path.begins_with("res://"):
		return _fail("GLTF/GLB files must be inside GameProject or imported into GameProject before wrapper generation.")

	var wrapper_absolute_path: String = _build_wrapper_absolute_path(runtime_model_absolute_path)
	var wrapper_res_path: String = _absolute_game_path_to_res_path(level_baker_root_absolute, wrapper_absolute_path)
	if not wrapper_res_path.begins_with("res://"):
		return _fail("Wrapper path could not be converted to a GameProject res:// path: %s" % wrapper_absolute_path)

	if _absolute_file_exists(wrapper_absolute_path):
		var reused_message: String = "Reused existing wrapper scene: %s" % wrapper_res_path
		if imported_external_model:
			reused_message = "%s %s" % [import_message, reused_message]
		return {
			"ok": true,
			"assigned_path": wrapper_res_path,
			"wrapper_created": false,
			"wrapper_reused": true,
			"imported_external_model": imported_external_model,
			"dependency_notes": dependency_notes,
			"source_path": original_source_path,
			"source_res_path": model_res_path,
			"runtime_model_path": runtime_model_absolute_path,
			"wrapper_path": wrapper_absolute_path,
			"wrapper_res_path": wrapper_res_path,
			"message": reused_message,
		}

	var write_result: Dictionary = _write_wrapper_scene_for_model(level_baker_root_absolute, runtime_model_absolute_path, wrapper_absolute_path, original_source_path, runtime_model_absolute_path)
	if not bool(write_result.get("ok", false)):
		return write_result

	var generated_message: String = "Generated wrapper scene: %s" % wrapper_res_path
	if imported_external_model:
		generated_message = "%s %s" % [import_message, generated_message]

	return {
		"ok": true,
		"assigned_path": wrapper_res_path,
		"wrapper_created": true,
		"wrapper_reused": false,
		"imported_external_model": imported_external_model,
		"dependency_notes": dependency_notes,
		"source_path": original_source_path,
		"source_res_path": model_res_path,
		"runtime_model_path": runtime_model_absolute_path,
		"wrapper_path": wrapper_absolute_path,
		"wrapper_res_path": wrapper_res_path,
		"message": generated_message,
	}

func _copy_external_model_to_game_project(level_baker_root_absolute: String, source_absolute_path: String, scene_field_key: String) -> Dictionary:
	var target_bucket: String = _bucket_for_scene_field(scene_field_key)
	var import_dir_absolute: String = _res_path_to_game_absolute_path(level_baker_root_absolute, MANAGED_IMPORT_ROOT_RES.path_join(target_bucket))
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(import_dir_absolute)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		return _fail("Failed creating managed model import directory: %s" % import_dir_absolute)

	var destination_absolute_path: String = _choose_model_destination_path(import_dir_absolute, source_absolute_path)
	var copied_main_file: bool = false
	if not FileAccess.file_exists(destination_absolute_path):
		var copy_error: Error = _copy_file_bytes(source_absolute_path, destination_absolute_path)
		if copy_error != OK:
			return _fail("Failed copying model into GameProject: %s -> %s" % [source_absolute_path, destination_absolute_path])
		copied_main_file = true

	var dependency_notes: Array[String] = []
	if source_absolute_path.get_extension().to_lower() == "gltf":
		dependency_notes = _copy_gltf_dependencies(source_absolute_path, destination_absolute_path)

	var imported_res_path: String = _absolute_game_path_to_res_path(level_baker_root_absolute, destination_absolute_path)
	var action_text: String = "Imported external model into GameProject: %s" % imported_res_path
	if not copied_main_file:
		action_text = "Reused matching imported model in GameProject: %s" % imported_res_path

	return {
		"ok": true,
		"imported_absolute_path": destination_absolute_path,
		"imported_res_path": imported_res_path,
		"dependency_notes": dependency_notes,
		"message": action_text,
	}

func _bucket_for_scene_field(scene_field_key: String) -> String:
	var normalized_key: String = scene_field_key.to_lower()
	if normalized_key.contains("floor"):
		return "floors"
	if normalized_key.contains("wall") or normalized_key.contains("corner") or normalized_key.contains("post"):
		return "walls"
	return "props"

func _choose_model_destination_path(import_dir_absolute: String, source_absolute_path: String) -> String:
	var base_name: String = source_absolute_path.replace("\\", "/").get_file().get_basename()
	var extension: String = source_absolute_path.get_extension()
	var first_destination: String = import_dir_absolute.path_join("%s.%s" % [base_name, extension]).simplify_path()
	if not FileAccess.file_exists(first_destination):
		return first_destination
	if _files_match(source_absolute_path, first_destination):
		return first_destination

	var index: int = 2
	while index < 10000:
		var candidate: String = import_dir_absolute.path_join("%s_%s.%s" % [base_name, index, extension]).simplify_path()
		if not FileAccess.file_exists(candidate):
			return candidate
		if _files_match(source_absolute_path, candidate):
			return candidate
		index += 1

	return import_dir_absolute.path_join("%s_%s.%s" % [base_name, Time.get_unix_time_from_system(), extension]).simplify_path()

func _copy_gltf_dependencies(source_gltf_absolute_path: String, target_gltf_absolute_path: String) -> Array[String]:
	var notes: Array[String] = []
	var file: FileAccess = FileAccess.open(source_gltf_absolute_path, FileAccess.READ)
	if file == null:
		notes.append("Could not read GLTF dependency list: %s" % source_gltf_absolute_path)
		return notes

	var file_text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(file_text)
	if not (parsed is Dictionary):
		notes.append("GLTF dependency copy skipped because the file could not be parsed as JSON: %s" % source_gltf_absolute_path)
		return notes

	var uris: Array[String] = []
	_collect_uri_values(parsed, uris)

	var source_dir: String = source_gltf_absolute_path.get_base_dir()
	var target_dir: String = target_gltf_absolute_path.get_base_dir()
	for uri in uris:
		if not _is_local_file_uri(uri):
			continue
		var dependency_source_path: String = _resolve_dependency_path(source_dir, uri)
		var dependency_target_path: String = target_dir.path_join(uri).simplify_path()
		if not FileAccess.file_exists(dependency_source_path):
			notes.append("GLTF dependency was referenced but not found: %s" % uri)
			continue
		var dependency_dir_error: Error = DirAccess.make_dir_recursive_absolute(dependency_target_path.get_base_dir())
		if dependency_dir_error != OK and dependency_dir_error != ERR_ALREADY_EXISTS:
			notes.append("Could not create dependency directory for: %s" % uri)
			continue
		if FileAccess.file_exists(dependency_target_path):
			if _files_match(dependency_source_path, dependency_target_path):
				continue
			notes.append("GLTF dependency already exists with different contents and was left unchanged: %s" % uri)
			continue
		var dependency_copy_error: Error = _copy_file_bytes(dependency_source_path, dependency_target_path)
		if dependency_copy_error == OK:
			notes.append("Copied GLTF dependency: %s" % uri)
		else:
			notes.append("Failed copying GLTF dependency: %s" % uri)

	return notes

func _collect_uri_values(value, output: Array[String]) -> void:
	if value is Dictionary:
		for key in value.keys():
			if str(key) == "uri":
				var uri_value: String = str(value[key])
				if not output.has(uri_value):
					output.append(uri_value)
			else:
				_collect_uri_values(value[key], output)
	elif value is Array:
		for child in value:
			_collect_uri_values(child, output)

func _is_local_file_uri(uri: String) -> bool:
	var clean_uri: String = uri.strip_edges()
	if clean_uri.is_empty():
		return false
	if clean_uri.begins_with("data:"):
		return false
	if clean_uri.contains("://"):
		return false
	return true

func _resolve_dependency_path(source_dir: String, uri: String) -> String:
	if uri.begins_with("/") or uri.contains(":/") or uri.contains(":\\"):
		return uri.replace("\\", "/").simplify_path()
	return source_dir.path_join(uri).simplify_path()

func _write_wrapper_scene_for_model(level_baker_root_absolute: String, model_absolute_path: String, wrapper_absolute_path: String, original_source_path: String, imported_model_absolute_path: String) -> Dictionary:
	var model_res_path: String = _absolute_game_path_to_res_path(level_baker_root_absolute, model_absolute_path)
	var wrapper_res_path: String = _absolute_game_path_to_res_path(level_baker_root_absolute, wrapper_absolute_path)
	if not model_res_path.begins_with("res://"):
		return _fail("Wrapper source model is not inside GameProject: %s" % model_absolute_path)
	if not wrapper_res_path.begins_with("res://"):
		return _fail("Wrapper scene is not inside GameProject: %s" % wrapper_absolute_path)

	var wrapper_text: String = _build_wrapper_scene_text(model_res_path, model_absolute_path.get_file().get_basename(), original_source_path, imported_model_absolute_path, wrapper_res_path)
	var write_error: Error = _write_text_file_absolute(wrapper_absolute_path, wrapper_text)
	if write_error != OK:
		return _fail("Failed writing wrapper scene: %s" % wrapper_absolute_path)
	if not _absolute_file_exists(wrapper_absolute_path):
		return _fail("Wrapper scene write reported success, but the file was not found afterward: %s" % wrapper_absolute_path)

	return {
		"ok": true,
		"source_res_path": model_res_path,
		"wrapper_res_path": wrapper_res_path,
	}

func _write_text_file_absolute(destination_absolute_path: String, text: String) -> Error:
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(destination_absolute_path.get_base_dir())
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		return make_dir_error
	var file: FileAccess = FileAccess.open(destination_absolute_path, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_string(text)
	file.flush()
	file.close()
	return OK

func _absolute_file_exists(absolute_path: String) -> bool:
	if FileAccess.file_exists(absolute_path):
		return true
	var directory: DirAccess = DirAccess.open(absolute_path.get_base_dir())
	if directory == null:
		return false
	return directory.file_exists(absolute_path.get_file())

func _copy_file_bytes(source_absolute_path: String, destination_absolute_path: String) -> Error:
	var source_path: String = source_absolute_path.replace("\\", "/").simplify_path()
	var destination_path: String = destination_absolute_path.replace("\\", "/").simplify_path()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty() and FileAccess.get_file_as_string(source_path).is_empty():
		return ERR_FILE_CANT_READ
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		return make_dir_error
	var file: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_buffer(bytes)
	file.flush()
	file.close()
	return OK

func _files_match(first_absolute_path: String, second_absolute_path: String) -> bool:
	if not FileAccess.file_exists(first_absolute_path) or not FileAccess.file_exists(second_absolute_path):
		return false
	return FileAccess.get_md5(first_absolute_path) == FileAccess.get_md5(second_absolute_path)

func _build_wrapper_absolute_path(model_absolute_path: String) -> String:
	var base_dir: String = model_absolute_path.get_base_dir()
	var base_name: String = model_absolute_path.get_file().get_basename()
	return base_dir.path_join("%s_wrapper.tscn" % base_name).simplify_path()

func _build_wrapper_scene_text(model_res_path: String, source_base_name: String, original_source_path: String, imported_model_absolute_path: String, wrapper_res_path: String = "") -> String:
	var wrapper_name: String = _to_scene_safe_name("%sWrapper" % source_base_name)
	return "\n".join([
		"[gd_scene load_steps=2 format=3]",
		"",
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_model\"]" % _escape_scene_string(model_res_path),
		"",
		"[node name=\"%s\" type=\"Node3D\"]" % _escape_scene_string(wrapper_name),
		"metadata/generated_by = \"%s\"" % _escape_scene_string(GENERATED_BY_NOTE),
		"metadata/generated_version = \"%s\"" % _escape_scene_string(GENERATED_VERSION),
		"metadata/source_model_path = \"%s\"" % _escape_scene_string(model_res_path),
		"metadata/original_external_source_path = \"%s\"" % _escape_scene_string(original_source_path),
		"metadata/imported_model_res_path = \"%s\"" % _escape_scene_string(model_res_path),
		"metadata/generated_wrapper_res_path = \"%s\"" % _escape_scene_string(wrapper_res_path),
		"metadata/m24_5_original_source_path = \"%s\"" % _escape_scene_string(original_source_path),
		"metadata/m24_5_imported_model_path = \"%s\"" % _escape_scene_string(imported_model_absolute_path),
		"metadata/m24_6_original_external_source_path = \"%s\"" % _escape_scene_string(original_source_path),
		"metadata/m24_6_imported_model_res_path = \"%s\"" % _escape_scene_string(model_res_path),
		"metadata/m24_6_generated_wrapper_res_path = \"%s\"" % _escape_scene_string(wrapper_res_path),
		"metadata/m24_6_generated_version = \"%s\"" % _escape_scene_string(GENERATED_VERSION),
		"",
		"[node name=\"Model\" parent=\".\" instance=ExtResource(\"1_model\")]",
		"",
	])

func _read_text(absolute_path: String) -> String:
	var clean_path: String = absolute_path.replace("\\", "/").simplify_path()
	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

func _extract_root_node_type(file_text: String) -> String:
	for raw_line in file_text.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("[node "):
			continue
		var type_key: String = 'type="'
		var start_index: int = line.find(type_key)
		if start_index == -1:
			return ""
		start_index += type_key.length()
		var end_index: int = line.find('"', start_index)
		if end_index == -1:
			return ""
		return line.substr(start_index, end_index - start_index)
	return ""

func _extract_wrapper_model_res_path(file_text: String) -> String:
	var metadata_path: String = _extract_metadata_string(file_text, "metadata/source_model_path")
	if metadata_path.begins_with("res://"):
		return metadata_path
	var imported_path: String = _extract_metadata_string(file_text, "metadata/imported_model_res_path")
	if imported_path.begins_with("res://"):
		return imported_path
	var m24_6_path: String = _extract_metadata_string(file_text, "metadata/m24_6_imported_model_res_path")
	if m24_6_path.begins_with("res://"):
		return m24_6_path
	return _extract_first_ext_resource_path(file_text)

func _extract_metadata_string(file_text: String, key: String) -> String:
	for raw_line in file_text.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with(key):
			continue
		var quote_start: int = line.find('"')
		if quote_start == -1:
			return ""
		var quote_end: int = line.find('"', quote_start + 1)
		if quote_end == -1:
			return ""
		return line.substr(quote_start + 1, quote_end - quote_start - 1)
	return ""

func _extract_first_ext_resource_path(file_text: String) -> String:
	for raw_line in file_text.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("[ext_resource"):
			continue
		var path_key: String = 'path="'
		var start_index: int = line.find(path_key)
		if start_index == -1:
			continue
		start_index += path_key.length()
		var end_index: int = line.find('"', start_index)
		if end_index == -1:
			continue
		var found_path: String = line.substr(start_index, end_index - start_index)
		if found_path.begins_with("res://"):
			return found_path
	return ""

func _count_occurrences(text: String, needle: String) -> int:
	var count: int = 0
	var search_from: int = 0
	while true:
		var found_index: int = text.find(needle, search_from)
		if found_index == -1:
			break
		count += 1
		search_from = found_index + needle.length()
	return count

func _resolve_scene_path(level_baker_root_absolute: String, user_path: String) -> String:
	var clean_path: String = user_path.replace("\\", "/").strip_edges()
	if clean_path.begins_with("/") or clean_path.contains(":/") or clean_path.contains(":\\"):
		return clean_path.simplify_path()
	if clean_path.begins_with("res://"):
		return _res_path_to_game_absolute_path(level_baker_root_absolute, clean_path)
	return _normalize_level_baker_root_absolute(level_baker_root_absolute).path_join(clean_path).simplify_path()

func _game_project_root_absolute(level_baker_root_absolute: String) -> String:
	var clean_root: String = _normalize_level_baker_root_absolute(level_baker_root_absolute)
	if clean_root.get_file() == "GameProject":
		return clean_root
	return clean_root.path_join("../GameProject").simplify_path()

func _normalize_level_baker_root_absolute(level_baker_root_absolute: String) -> String:
	var clean_root: String = level_baker_root_absolute.replace("\\", "/").strip_edges()
	if clean_root.is_empty() or clean_root == "res://" or clean_root.begins_with("res://"):
		clean_root = ProjectSettings.globalize_path("res://").replace("\\", "/").strip_edges()
	clean_root = clean_root.simplify_path()
	while clean_root.ends_with("/"):
		clean_root = clean_root.trim_suffix("/")
	return clean_root

func _to_scene_safe_name(raw_name: String) -> String:
	var output: String = ""
	for index in range(raw_name.length()):
		var code: int = raw_name.unicode_at(index)
		var is_uppercase: bool = code >= 65 and code <= 90
		var is_lowercase: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if is_uppercase or is_lowercase or is_digit or is_underscore:
			output += raw_name.substr(index, 1)
		else:
			output += "_"
	if output.is_empty():
		output = "ModelWrapper"
	var first_code: int = output.unicode_at(0)
	if first_code >= 48 and first_code <= 57:
		output = "Model_%s" % output
	return output

func _absolute_game_path_to_res_path(level_baker_root_absolute: String, absolute_path: String) -> String:
	var clean_absolute: String = absolute_path.replace("\\", "/").simplify_path()
	var game_project_root: String = _game_project_root_absolute(level_baker_root_absolute)
	if clean_absolute.begins_with(game_project_root):
		var suffix: String = clean_absolute.trim_prefix(game_project_root).trim_prefix("/")
		return "res://%s" % suffix
	return clean_absolute

func _res_path_to_game_absolute_path(level_baker_root_absolute: String, res_path: String) -> String:
	var suffix: String = res_path.trim_prefix("res://").trim_prefix("/")
	return _game_project_root_absolute(level_baker_root_absolute).path_join(suffix).simplify_path()

func _is_inside_game_project(level_baker_root_absolute: String, absolute_path: String) -> bool:
	return absolute_path.replace("\\", "/").simplify_path().begins_with(_game_project_root_absolute(level_baker_root_absolute))

func _escape_scene_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")

func _no_repair(message: String) -> Dictionary:
	return {
		"ok": true,
		"repaired": false,
		"message": message,
	}

func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
