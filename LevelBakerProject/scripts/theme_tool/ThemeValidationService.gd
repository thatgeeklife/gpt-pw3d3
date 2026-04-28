extends RefCounted

const MODEL_WRAPPER_BUILDER_SCRIPT := preload("res://scripts/theme_tool/ModelWrapperBuilder.gd")

const SCENE_PATH_FIELDS: Array[String] = [
	"play_floor_scene_path",
	"edge_floor_scene_path",
	"outer_floor_scene_path",
	"straight_wall_scene_a_path",
	"straight_wall_scene_b_path",
	"straight_wall_scene_c_path",
	"corner_post_scene_a_path",
	"corner_post_scene_b_path",
]

const WALL_SCENE_FIELDS: Array[String] = [
	"straight_wall_scene_a_path",
	"straight_wall_scene_b_path",
	"straight_wall_scene_c_path",
	"corner_post_scene_a_path",
	"corner_post_scene_b_path",
]

var _model_wrapper_builder = MODEL_WRAPPER_BUILDER_SCRIPT.new()

func validate_theme_data(theme_data: Dictionary, level_baker_root_absolute: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var info: Array[String] = []
	var asset_health: Array[Dictionary] = []

	var theme_id: String = str(theme_data.get("theme_id", "")).strip_edges()
	var theme_name: String = str(theme_data.get("theme_name", "")).strip_edges()
	if theme_id.is_empty():
		errors.append("Theme ID is required.")
	if theme_name.is_empty():
		errors.append("Theme Name is required.")

	var expected_floor_size: float = float(theme_data.get("expected_floor_piece_world_size", 0.0))
	var expected_wall_length: float = float(theme_data.get("expected_wall_segment_world_length", 0.0))
	var cell_world_size: float = float(theme_data.get("cell_world_size", 0.0))
	var wall_height: float = float(theme_data.get("wall_height", 0.0))
	var wall_thickness: float = float(theme_data.get("wall_thickness", 0.0))

	if expected_floor_size <= 0.0:
		errors.append("Expected floor piece world size must be greater than 0.")
	if expected_wall_length <= 0.0:
		errors.append("Expected wall segment world length must be greater than 0.")
	if cell_world_size <= 0.0:
		errors.append("Cell world size must be greater than 0.")
	if wall_height <= 0.0:
		errors.append("Wall height must be greater than 0.")
	if wall_thickness <= 0.0:
		errors.append("Wall thickness must be greater than 0.")

	var common_weight: int = int(theme_data.get("wall_variant_weight_common", 0))
	var inset_weight: int = int(theme_data.get("wall_variant_weight_inset", 0))
	var buttress_weight: int = int(theme_data.get("wall_variant_weight_buttress", 0))
	if common_weight <= 0 and inset_weight <= 0 and buttress_weight <= 0:
		errors.append("At least one wall variant weight must be greater than 0.")

	var authored_scene_pack_id: String = str(theme_data.get("authored_scene_pack_id", "")).strip_edges()
	var assigned_scene_paths: Array[String] = []
	for field_name in SCENE_PATH_FIELDS:
		var path_value: String = str(theme_data.get(field_name, "")).strip_edges()
		if path_value.is_empty():
			continue
		assigned_scene_paths.append(path_value)

	if not assigned_scene_paths.is_empty() and authored_scene_pack_id.is_empty():
		warnings.append("Authored Scene Pack ID is empty even though authored scene paths are assigned.")

	var duplicate_tracker: Dictionary = {}
	for path_value in assigned_scene_paths:
		duplicate_tracker[path_value] = int(duplicate_tracker.get(path_value, 0)) + 1
	for path_value in duplicate_tracker.keys():
		if int(duplicate_tracker[path_value]) > 1:
			warnings.append("Scene path is assigned to multiple slots: %s" % path_value)

	for field_name in SCENE_PATH_FIELDS:
		var path_value: String = str(theme_data.get(field_name, "")).strip_edges()
		var health: Dictionary = _model_wrapper_builder.inspect_scene_path(level_baker_root_absolute, field_name, path_value)
		asset_health.append(health)
		if path_value.is_empty():
			warnings.append("%s is not assigned. Runtime fallback will be used." % field_name)
			continue

		var status_text: String = str(health.get("status", "FAIL"))
		var notes: Array = Array(health.get("notes", []))
		if status_text == "FAIL":
			for note in notes:
				errors.append("%s: %s" % [field_name, str(note)])
		elif status_text == "WARN":
			for note in notes:
				warnings.append("%s: %s" % [field_name, str(note)])

		if field_name in WALL_SCENE_FIELDS and bool(health.get("file_exists", false)):
			var absolute_path: String = str(health.get("absolute_path", ""))
			var file_text: String = _read_text(absolute_path)
			if "CollisionShape3D" not in file_text and "StaticBody3D" not in file_text:
				warnings.append("%s has no authored collision nodes. Runtime fallback collision will still be used: %s" % [field_name, path_value])

	if assigned_scene_paths.is_empty():
		info.append("No authored scene paths assigned yet. The runtime will rely on primitive fallback rendering.")
	else:
		info.append("Assigned authored scene paths: %s" % assigned_scene_paths.size())

	info.append("Expected floor footprint: %s x %s world units." % [expected_floor_size, expected_floor_size])
	info.append("Expected wall segment length: %s world units." % expected_wall_length)
	info.append("Expected wall forward axis: %s" % str(theme_data.get("expected_wall_forward_axis", "+Z")))

	return {
		"is_valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"info": info,
		"asset_health": asset_health,
	}

func build_report_text(report: Dictionary) -> String:
	var lines: Array[String] = []
	var is_valid: bool = bool(report.get("is_valid", false))
	lines.append("Validation Result: %s" % ("PASS" if is_valid else "FAIL"))
	lines.append("")

	_append_asset_health_section(lines, Array(report.get("asset_health", [])))

	var errors: Array = Array(report.get("errors", []))
	var warnings: Array = Array(report.get("warnings", []))
	var info: Array = Array(report.get("info", []))

	lines.append("")
	lines.append("Errors: %s" % errors.size())
	for entry in errors:
		lines.append("- %s" % str(entry))

	lines.append("")
	lines.append("Warnings: %s" % warnings.size())
	for entry in warnings:
		lines.append("- %s" % str(entry))

	lines.append("")
	lines.append("Info: %s" % info.size())
	for entry in info:
		lines.append("- %s" % str(entry))

	return "\n".join(lines)

func _append_asset_health_section(lines: Array[String], asset_health: Array) -> void:
	lines.append("Asset Health: %s slot(s)" % asset_health.size())
	for raw_item in asset_health:
		var item: Dictionary = raw_item
		var field_name: String = str(item.get("field", "<unknown>"))
		var stored_path: String = str(item.get("stored_path", ""))
		if stored_path.is_empty():
			stored_path = "<empty>"
		var wrapper_source: String = str(item.get("wrapper_source_res_path", ""))
		if wrapper_source.is_empty():
			wrapper_source = "<none>"
		lines.append("")
		lines.append("[%s]" % field_name)
		lines.append("Status: %s" % str(item.get("status", "UNKNOWN")))
		lines.append("Stored Path: %s" % stored_path)
		lines.append("Resolved Absolute Path: %s" % _value_or_none(str(item.get("absolute_path", ""))))
		lines.append("File Exists: %s" % _yes_no(bool(item.get("file_exists", false))))
		lines.append("Generated Wrapper: %s" % _yes_no(bool(item.get("is_wrapper", false))))
		lines.append("Wrapper Source: %s" % wrapper_source)
		lines.append("Wrapper Source Absolute Path: %s" % _value_or_none(str(item.get("wrapper_source_absolute_path", ""))))
		lines.append("Model Exists: %s" % _yes_no(bool(item.get("wrapper_source_exists", false))))
		lines.append("Root Type: %s" % _value_or_none(str(item.get("root_type", ""))))
		lines.append("Node Count: %s" % int(item.get("node_count", 0)))
		lines.append("Mesh Marker: %s" % _yes_no(bool(item.get("mesh_marker", false))))
		lines.append("Model Instance Marker: %s" % _yes_no(bool(item.get("model_instance_marker", false))))
		var notes: Array = Array(item.get("notes", []))
		for note in notes:
			lines.append("- %s" % str(note))

func _read_text(absolute_path: String) -> String:
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

func _yes_no(value: bool) -> String:
	if value:
		return "YES"
	return "NO"

func _value_or_none(value: String) -> String:
	if value.strip_edges().is_empty():
		return "<none>"
	return value
