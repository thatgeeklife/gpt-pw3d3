extends Control

const BAKED_LEVEL_DEFINITION_SCRIPT := preload("res://scripts/shared/BakedLevelDefinition.gd")
const BAKE_VALIDATION_SCRIPT := preload("res://scripts/BakeValidation.gd")
const BAKED_LEVEL_BUILDER_SCRIPT := preload("res://scripts/BakedLevelBuilder.gd")

@onready var source_image_path_edit: LineEdit = $MarginContainer/VBoxContainer/FormGrid/SourceImagePathEdit
@onready var level_id_edit: LineEdit = $MarginContainer/VBoxContainer/FormGrid/LevelIdEdit
@onready var level_name_edit: LineEdit = $MarginContainer/VBoxContainer/FormGrid/LevelNameEdit
@onready var theme_id_edit: LineEdit = $MarginContainer/VBoxContainer/FormGrid/ThemeIdEdit
@onready var output_path_edit: LineEdit = $MarginContainer/VBoxContainer/FormGrid/OutputPathEdit
@onready var status_log: TextEdit = $MarginContainer/VBoxContainer/StatusLog
@onready var source_file_dialog: FileDialog = $SourceImageFileDialog
@onready var output_file_dialog: FileDialog = $OutputPathFileDialog

var _validator = BAKE_VALIDATION_SCRIPT.new()
var _builder = BAKED_LEVEL_BUILDER_SCRIPT.new()

func _ready() -> void:
	_seed_default_values()
	_append_log("M19.3 patch 2 ready.")
	_append_log("Browse Source opens a file dialog for the source image.")
	_append_log("Browse Output opens a save dialog for the baked .tres path.")
	_append_log("Absolute paths now resolve correctly, and sibling SharedLevelContent paths are converted back to ../SharedLevelContent/... automatically.")

func _seed_default_values() -> void:
	source_image_path_edit.text = "../SharedLevelContent/source_images/sample_forest.png"
	level_id_edit.text = "sample_forest"
	level_name_edit.text = "Sample Forest"
	theme_id_edit.text = "forest_theme"
	output_path_edit.text = "../SharedLevelContent/baked_levels/sample_forest_level.tres"

func _on_browse_source_pressed() -> void:
	source_file_dialog.current_dir = _resolve_dialog_dir(source_image_path_edit.text, "../SharedLevelContent/source_images")
	source_file_dialog.popup_centered_ratio(0.7)

func _on_browse_output_pressed() -> void:
	output_file_dialog.current_dir = _resolve_dialog_dir(output_path_edit.text, "../SharedLevelContent/baked_levels")
	output_file_dialog.current_file = output_path_edit.text.get_file()
	output_file_dialog.popup_centered_ratio(0.7)

func _on_source_file_selected(path: String) -> void:
	source_image_path_edit.text = _to_preferred_display_path(path)

func _on_output_file_selected(path: String) -> void:
	var final_path: String = path
	if not final_path.to_lower().ends_with(".tres"):
		final_path += ".tres"
	output_path_edit.text = _to_preferred_display_path(final_path)

func _on_validate_pressed() -> void:
	status_log.clear()
	_append_log("Validation pass:")
	var input_result: Dictionary = _validator.validate_inputs(
		source_image_path_edit.text,
		level_id_edit.text,
		level_name_edit.text,
		theme_id_edit.text,
		output_path_edit.text
	)
	_append_lines(input_result["lines"])
	if not bool(input_result["is_valid"]):
		_append_log("Validation result: FAIL")
		return

	var absolute_source_path: String = _resolve_path(source_image_path_edit.text.strip_edges())
	var image := Image.new()
	var load_error: Error = image.load(absolute_source_path)
	if load_error != OK:
		_append_log("- Image load failed with error code: %s" % load_error)
		_append_log("Validation result: FAIL")
		return

	var image_result: Dictionary = _validator.validate_image(absolute_source_path, image)
	_append_lines(image_result["lines"])
	_append_log("Validation result: %s" % ("PASS" if bool(image_result["is_valid"]) else "FAIL"))

func _on_create_sample_pressed() -> void:
	status_log.clear()
	_append_log("Creating in-memory sample baked definition...")
	var sample: Resource = BAKED_LEVEL_DEFINITION_SCRIPT.new()
	sample.level_id = level_id_edit.text.strip_edges()
	sample.level_name = level_name_edit.text.strip_edges()
	sample.theme_id = theme_id_edit.text.strip_edges()
	sample.default_theme_id = sample.theme_id
	sample.source_image_path = source_image_path_edit.text.strip_edges()
	sample.image_width = 16
	sample.image_height = 16
	sample.visible_pixel_count = 1
	sample.bounds_min = Vector2i.ZERO
	sample.bounds_max = Vector2i.ZERO
	sample.palette_colors.append(Color.WHITE)
	sample.palette_codes.append("A1")
	sample.palette_keys.append("255_255_255_255")
	sample.pixel_ids.append(0)
	sample.grid_x.append(0)
	sample.grid_y.append(0)
	sample.palette_indices.append(0)
	_append_log("Sample resource created.")
	_append_log("Valid definition: %s" % str(sample.is_valid_definition()))

func _on_bake_level_pressed() -> void:
	status_log.clear()
	_append_log("Bake pass:")
	var input_result: Dictionary = _validator.validate_inputs(
		source_image_path_edit.text,
		level_id_edit.text,
		level_name_edit.text,
		theme_id_edit.text,
		output_path_edit.text
	)
	_append_lines(input_result["lines"])
	if not bool(input_result["is_valid"]):
		_append_log("Bake result: FAIL")
		return

	var absolute_source_path: String = _resolve_path(source_image_path_edit.text.strip_edges())
	var image := Image.new()
	var load_error: Error = image.load(absolute_source_path)
	if load_error != OK:
		_append_log("- Image load failed with error code: %s" % load_error)
		_append_log("Bake result: FAIL")
		return

	var image_result: Dictionary = _validator.validate_image(absolute_source_path, image)
	_append_lines(image_result["lines"])
	if not bool(image_result["is_valid"]):
		_append_log("Bake result: FAIL")
		return

	var baked_definition: Resource = _builder.build_from_image(
		absolute_source_path,
		source_image_path_edit.text.strip_edges(),
		level_id_edit.text,
		level_name_edit.text,
		theme_id_edit.text
	)
	if baked_definition == null:
		_append_log("- Builder returned null baked definition.")
		_append_log("Bake result: FAIL")
		return

	var absolute_output_path: String = _resolve_path(output_path_edit.text.strip_edges())
	var save_error: Error = _builder.save_baked_definition(baked_definition, absolute_output_path)
	if save_error != OK:
		_append_log("- TRES save failed with error code: %s" % save_error)
		_append_log("Bake result: FAIL")
		return

	var absolute_json_path: String = absolute_output_path.get_basename() + ".json"
	var json_save_error: Error = _builder.save_baked_definition_json(baked_definition, absolute_json_path)
	if json_save_error != OK:
		_append_log("- JSON save failed with error code: %s" % json_save_error)
		_append_log("Bake result: FAIL")
		return

	_append_log("- Baked .tres saved.")
	_append_log("- Companion .json saved.")
	_append_log("- TRES output: %s" % absolute_output_path)
	_append_log("- JSON output: %s" % absolute_json_path)
	_append_log("Bake result: PASS")

func _resolve_dialog_dir(current_value: String, fallback_rel: String) -> String:
	var trimmed: String = current_value.strip_edges()
	if not trimmed.is_empty():
		return _resolve_path(trimmed).get_base_dir()
	return _resolve_path(fallback_rel)

func _to_preferred_display_path(absolute_or_selected_path: String) -> String:
	var absolute_path: String = absolute_or_selected_path
	if not _is_absolute_path(absolute_path):
		absolute_path = _resolve_path(absolute_path)

	var project_root: String = ProjectSettings.globalize_path("res://").simplify_path()
	var shared_root: String = project_root.path_join("../SharedLevelContent").simplify_path()

	if absolute_path.begins_with(shared_root):
		var suffix: String = absolute_path.trim_prefix(shared_root).trim_prefix("/")
		return "../SharedLevelContent/%s" % suffix

	if absolute_path.begins_with(project_root):
		var suffix2: String = absolute_path.trim_prefix(project_root).trim_prefix("/")
		return suffix2

	return absolute_path

func _resolve_path(user_path: String) -> String:
	if user_path.begins_with("res://") or user_path.begins_with("user://"):
		return ProjectSettings.globalize_path(user_path)
	if _is_absolute_path(user_path):
		return user_path

	var project_root: String = ProjectSettings.globalize_path("res://")
	return project_root.path_join(user_path).simplify_path()

func _is_absolute_path(path_value: String) -> bool:
	return path_value.begins_with("/") or path_value.contains(":/") or path_value.contains(":\\")

func _append_lines(lines: Array) -> void:
	for line in lines:
		_append_log(str(line))

func _append_log(message: String) -> void:
	if status_log.text.is_empty():
		status_log.text = message
	else:
		status_log.text += "\n" + message