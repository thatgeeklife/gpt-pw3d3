extends Control

const THEME_DEFINITION_MODEL_SCRIPT := preload("res://scripts/theme_tool/ThemeDefinitionModel.gd")
const THEME_DEFINITION_IO_SCRIPT := preload("res://scripts/theme_tool/ThemeDefinitionIO.gd")
const THEME_VALIDATION_SERVICE_SCRIPT := preload("res://scripts/theme_tool/ThemeValidationService.gd")
const MODEL_WRAPPER_BUILDER_SCRIPT := preload("res://scripts/theme_tool/ModelWrapperBuilder.gd")

const TEXT_FIELDS: Array[String] = [
	"theme_id",
	"theme_name",
	"authored_scene_pack_id",
	"play_floor_scene_path",
	"edge_floor_scene_path",
	"outer_floor_scene_path",
	"straight_wall_scene_a_path",
	"straight_wall_scene_b_path",
	"straight_wall_scene_c_path",
	"corner_post_scene_a_path",
	"corner_post_scene_b_path",
	"expected_wall_forward_axis",
	"expected_origin_note",
]

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

const FLOAT_FIELDS: Array[String] = [
	"tile_height",
	"wall_height",
	"wall_thickness",
	"tile_muting_strength",
	"cell_world_size",
	"wall_corner_post_scale",
	"expected_floor_piece_world_size",
	"expected_wall_segment_world_length",
]

const INT_FIELDS: Array[String] = [
	"wall_variant_weight_common",
	"wall_variant_weight_inset",
	"wall_variant_weight_buttress",
	"wall_small_room_disable_buttress_under_perimeter",
]

const COLOR_FIELDS: Array[String] = [
	"floor_color",
	"edge_floor_color",
	"border_floor_color",
	"wall_color",
]

@onready var form_vbox: VBoxContainer = $MarginContainer/VBox/BodySplit/LeftPanel/ScrollContainer/FormVBox
@onready var validation_report: TextEdit = $MarginContainer/VBox/BodySplit/RightPanel/ValidationReport
@onready var status_log: TextEdit = $MarginContainer/VBox/BodySplit/RightPanel/StatusLog
@onready var current_path_label: Label = $MarginContainer/VBox/CurrentPathLabel
@onready var theme_load_dialog: FileDialog = $ThemeLoadDialog
@onready var theme_save_dialog: FileDialog = $ThemeSaveDialog
@onready var scene_pick_dialog: FileDialog = $ScenePickDialog

var _model = THEME_DEFINITION_MODEL_SCRIPT.new()
var _io = THEME_DEFINITION_IO_SCRIPT.new()
var _validation_service = THEME_VALIDATION_SERVICE_SCRIPT.new()
var _model_wrapper_builder = MODEL_WRAPPER_BUILDER_SCRIPT.new()
var _field_controls: Dictionary = {}
var _scene_field_buttons: Dictionary = {}
var _current_scene_pick_field: String = ""
var _validation_run_index: int = 0

func _ready() -> void:
	_model.reset_to_defaults()
	_build_form()
	_refresh_form_from_model()
	_append_log("M24.6.1 theme authoring tool ready.")
	_append_log("Scene picker accepts .tscn directly, wraps GameProject .gltf/.glb, auto-imports external .gltf/.glb, and can rebuild generated wrappers. M24.6.1 uses stronger validation path checks.")
	_append_log("Use Validate Theme to check paths, wrapper health, and theme setup.")
	_append_log("Use Export to GameProject to write to ../GameProject/data/levels/themes/.")
	_run_validation()

func _build_form() -> void:
	for child in form_vbox.get_children():
		child.queue_free()
	_field_controls.clear()
	_scene_field_buttons.clear()

	_add_section_header("Theme Info")
	_add_text_field("theme_id", "Theme ID")
	_add_text_field("theme_name", "Theme Name")
	_add_text_field("authored_scene_pack_id", "Scene Pack ID")

	_add_section_header("Colors")
	_add_color_field("floor_color", "Floor Color", Color(0.16, 0.16, 0.16, 1.0))
	_add_color_field("edge_floor_color", "Edge Floor Color", Color(0.14, 0.14, 0.14, 1.0))
	_add_color_field("border_floor_color", "Border Floor Color", Color(0.12, 0.12, 0.12, 1.0))
	_add_color_field("wall_color", "Wall Color", Color(0.22, 0.22, 0.22, 1.0))

	_add_section_header("Metrics")
	_add_float_field("tile_height", "Tile Height", 0.0, 20.0, 0.01)
	_add_float_field("wall_height", "Wall Height", 0.0, 50.0, 0.05)
	_add_float_field("wall_thickness", "Wall Thickness", 0.0, 10.0, 0.01)
	_add_float_field("tile_muting_strength", "Tile Muting Strength", 0.0, 2.0, 0.01)
	_add_float_field("cell_world_size", "Cell World Size", 0.1, 20.0, 0.05)

	_add_section_header("Wall Variation")
	_add_int_field("wall_variant_weight_common", "Common Weight", 0, 999)
	_add_int_field("wall_variant_weight_inset", "Inset Weight", 0, 999)
	_add_int_field("wall_variant_weight_buttress", "Buttress Weight", 0, 999)
	_add_int_field("wall_small_room_disable_buttress_under_perimeter", "Buttress Min Perimeter", 0, 999)
	_add_float_field("wall_corner_post_scale", "Corner Post Scale", 0.1, 10.0, 0.01)

	_add_section_header("Floor Scene Paths")
	_add_scene_path_field("play_floor_scene_path", "Play Floor Scene")
	_add_scene_path_field("edge_floor_scene_path", "Edge Floor Scene")
	_add_scene_path_field("outer_floor_scene_path", "Outer Floor Scene")

	_add_section_header("Wall Scene Paths")
	_add_scene_path_field("straight_wall_scene_a_path", "Straight Wall A")
	_add_scene_path_field("straight_wall_scene_b_path", "Straight Wall B")
	_add_scene_path_field("straight_wall_scene_c_path", "Straight Wall C")
	_add_scene_path_field("corner_post_scene_a_path", "Corner Post A")
	_add_scene_path_field("corner_post_scene_b_path", "Corner Post B")

	_add_section_header("Contract")
	_add_float_field("expected_floor_piece_world_size", "Expected Floor Piece Size", 0.1, 50.0, 0.05)
	_add_float_field("expected_wall_segment_world_length", "Expected Wall Segment Length", 0.1, 50.0, 0.05)
	_add_text_field("expected_wall_forward_axis", "Expected Wall Forward Axis")
	_add_multiline_text_field("expected_origin_note", "Expected Origin Note")

func _add_section_header(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	form_vbox.add_child(label)

func _add_row_container() -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	form_vbox.add_child(row)
	return row

func _add_label(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	parent.add_child(label)

func _add_text_field(key: String, label_text: String) -> void:
	var row := _add_row_container()
	_add_label(row, label_text)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_text_field_changed.bind(key))
	row.add_child(edit)
	_field_controls[key] = edit

func _add_multiline_text_field(key: String, label_text: String) -> void:
	var row := _add_row_container()
	_add_label(row, label_text)
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(0.0, 110.0)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_text_edit_changed.bind(key, edit))
	row.add_child(edit)
	_field_controls[key] = edit

func _add_float_field(key: String, label_text: String, min_value: float, max_value: float, step_value: float) -> void:
	var row := _add_row_container()
	_add_label(row, label_text)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step_value
	spin.allow_greater = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_spinbox_float_changed.bind(key))
	row.add_child(spin)
	_field_controls[key] = spin

func _add_int_field(key: String, label_text: String, min_value: int, max_value: int) -> void:
	var row := _add_row_container()
	_add_label(row, label_text)
	var spin := SpinBox.new()
	spin.min_value = float(min_value)
	spin.max_value = float(max_value)
	spin.step = 1.0
	spin.allow_greater = true
	spin.rounded = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_spinbox_int_changed.bind(key))
	row.add_child(spin)
	_field_controls[key] = spin

func _add_color_field(key: String, label_text: String, fallback_color: Color) -> void:
	var row := _add_row_container()
	_add_label(row, label_text)
	var picker := ColorPickerButton.new()
	picker.color = fallback_color
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.color_changed.connect(_on_color_changed.bind(key))
	row.add_child(picker)
	_field_controls[key] = picker

func _add_scene_path_field(key: String, label_text: String) -> void:
	var row := _add_row_container()
	_add_label(row, label_text)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_text_field_changed.bind(key))
	hbox.add_child(edit)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_on_scene_browse_pressed.bind(key))
	hbox.add_child(browse_button)

	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_on_scene_clear_pressed.bind(key))
	hbox.add_child(clear_button)

	var rebuild_button := Button.new()
	rebuild_button.text = "Rebuild Wrapper"
	rebuild_button.tooltip_text = "Regenerate the assigned _wrapper.tscn from its sibling .gltf/.glb model."
	rebuild_button.pressed.connect(_on_scene_rebuild_pressed.bind(key))
	hbox.add_child(rebuild_button)

	_field_controls[key] = edit
	_scene_field_buttons[key] = browse_button

func _refresh_form_from_model() -> void:
	for key in TEXT_FIELDS:
		if not _field_controls.has(key):
			continue
		var control = _field_controls[key]
		if control is LineEdit:
			control.text = str(_model.get_value(key, ""))
		elif control is TextEdit:
			control.text = str(_model.get_value(key, ""))

	for key in FLOAT_FIELDS:
		if not _field_controls.has(key):
			continue
		var control = _field_controls[key] as SpinBox
		control.value = float(_model.get_value(key, 0.0))

	for key in INT_FIELDS:
		if not _field_controls.has(key):
			continue
		var control = _field_controls[key] as SpinBox
		control.value = int(_model.get_value(key, 0))

	for key in COLOR_FIELDS:
		if not _field_controls.has(key):
			continue
		var picker = _field_controls[key] as ColorPickerButton
		picker.color = _model.get_color(key, Color.WHITE)

	_refresh_path_label()

func _refresh_path_label() -> void:
	var file_text: String = "<unsaved>"
	if not _model.current_file_path.is_empty():
		file_text = _io.to_preferred_display_path(ProjectSettings.globalize_path("res://"), _model.current_file_path)
	if _model.is_dirty:
		file_text += " *"
	current_path_label.text = "Current file: %s" % file_text

func _on_text_field_changed(new_text: String, key: String) -> void:
	_model.set_value(key, new_text)
	_refresh_path_label()

func _on_text_edit_changed(key: String, edit: TextEdit) -> void:
	_model.set_value(key, edit.text)
	_refresh_path_label()

func _on_spinbox_float_changed(value: float, key: String) -> void:
	_model.set_value(key, value)
	_refresh_path_label()

func _on_spinbox_int_changed(value: float, key: String) -> void:
	_model.set_value(key, int(round(value)))
	_refresh_path_label()

func _on_color_changed(color_value: Color, key: String) -> void:
	_model.set_color(key, color_value)
	_refresh_path_label()

func _on_scene_browse_pressed(key: String) -> void:
	_current_scene_pick_field = key
	var current_value: String = str(_model.get_value(key, ""))
	var project_root: String = ProjectSettings.globalize_path("res://")
	if not current_value.is_empty():
		scene_pick_dialog.current_dir = _io.resolve_path(project_root, current_value).get_base_dir()
	else:
		scene_pick_dialog.current_dir = project_root.path_join("../GameProject/scenes").simplify_path()
	scene_pick_dialog.popup_centered_ratio(0.8)

func _on_scene_clear_pressed(key: String) -> void:
	_model.set_value(key, "")
	if _field_controls.has(key):
		var edit = _field_controls[key] as LineEdit
		edit.text = ""
	_refresh_path_label()
	_run_validation("Cleared scene path: %s" % key)

func _on_scene_rebuild_pressed(key: String) -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var assigned_path: String = str(_model.get_value(key, "")).strip_edges()
	if assigned_path.is_empty():
		_append_log("Rebuild skipped for %s: no scene path is assigned." % key)
		var empty_report: Dictionary = _run_validation("Rebuild skipped: %s" % key)
		_append_validation_summary(empty_report)
		return

	var rebuild_result: Dictionary = _model_wrapper_builder.rebuild_wrapper_for_scene_path(project_root, assigned_path, key)
	if not bool(rebuild_result.get("ok", false)):
		_append_log("Rebuild failed for %s: %s" % [key, str(rebuild_result.get("error", "Unknown error."))])
		var failed_report: Dictionary = _run_validation("Rebuild failed: %s" % key)
		_append_validation_summary(failed_report)
		return

	var rebuilt_path: String = str(rebuild_result.get("assigned_path", assigned_path))
	_model.set_value(key, rebuilt_path)
	if _field_controls.has(key):
		var edit = _field_controls[key] as LineEdit
		edit.text = rebuilt_path
	_refresh_path_label()
	_append_log(str(rebuild_result.get("message", "Wrapper rebuilt.")))
	var report: Dictionary = _run_validation("Rebuild Wrapper: %s" % key)
	_append_validation_summary(report)

func _on_new_theme_pressed() -> void:
	_model.reset_to_defaults()
	_refresh_form_from_model()
	status_log.clear()
	_append_log("Started a new theme definition.")
	_run_validation()

func _on_load_theme_pressed() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	theme_load_dialog.current_dir = project_root.path_join("../GameProject/data/levels/themes").simplify_path()
	theme_load_dialog.popup_centered_ratio(0.8)

func _on_save_theme_pressed() -> void:
	if _model.current_file_path.is_empty():
		_on_save_theme_as_pressed()
		return
	_save_to_absolute_path(_model.current_file_path)

func _on_save_theme_as_pressed() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var suggested_path: String = _io.get_default_export_absolute_path(project_root, str(_model.get_value("theme_id", "new_theme")))
	theme_save_dialog.current_dir = suggested_path.get_base_dir()
	theme_save_dialog.current_file = suggested_path.get_file()
	theme_save_dialog.popup_centered_ratio(0.8)

func _on_export_theme_pressed() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var export_path: String = _io.get_default_export_absolute_path(project_root, str(_model.get_value("theme_id", "new_theme")))
	_save_to_absolute_path(export_path)
	_append_log("Export completed. Runtime theme path: %s" % _io.to_preferred_display_path(project_root, export_path))
	var report: Dictionary = _run_validation("Export to GameProject")
	_append_validation_summary(report)

func _on_validate_theme_pressed() -> void:
	var report: Dictionary = _run_validation("Validate Theme button")
	_append_validation_summary(report)

func _on_theme_load_file_selected(path: String) -> void:
	var result: Dictionary = _io.load_theme_json(path)
	if not bool(result.get("ok", false)):
		_append_log("Load failed: %s" % str(result.get("error", "Unknown error.")))
		return
	_model.load_from_dictionary(Dictionary(result.get("data", {})), path)
	_refresh_form_from_model()
	status_log.clear()
	_append_log("Loaded theme JSON.")
	_append_log("Loaded: %s" % _io.to_preferred_display_path(ProjectSettings.globalize_path("res://"), path))
	_run_validation()

func _on_theme_save_file_selected(path: String) -> void:
	var final_path: String = path
	if not final_path.to_lower().ends_with(".json"):
		final_path += ".json"
	_save_to_absolute_path(final_path)
	var report: Dictionary = _run_validation("Save Theme As")
	_append_validation_summary(report)

func _on_scene_pick_file_selected(path: String) -> void:
	if _current_scene_pick_field.is_empty():
		return
	var project_root: String = ProjectSettings.globalize_path("res://")
	var wrapper_result: Dictionary = _model_wrapper_builder.prepare_selected_theme_piece(project_root, path, _current_scene_pick_field)
	if not bool(wrapper_result.get("ok", false)):
		_append_log("Scene assignment failed for %s: %s" % [_current_scene_pick_field, str(wrapper_result.get("error", "Unknown error."))])
		_run_validation()
		return

	var assigned_path: String = str(wrapper_result.get("assigned_path", ""))
	if assigned_path.is_empty():
		_append_log("Scene assignment failed for %s: wrapper builder returned an empty assigned path." % _current_scene_pick_field)
		_run_validation()
		return
	if not _model_wrapper_builder.game_res_file_exists(project_root, assigned_path):
		var repair_result: Dictionary = _model_wrapper_builder.repair_missing_wrapper_scene_path(project_root, assigned_path, _current_scene_pick_field)
		if not bool(repair_result.get("ok", false)):
			_append_log("Scene assignment failed for %s: %s" % [_current_scene_pick_field, str(repair_result.get("error", "Wrapper path did not exist and repair failed."))])
			_run_validation()
			return
		if not _model_wrapper_builder.game_res_file_exists(project_root, assigned_path):
			_append_log("Scene assignment failed for %s: wrapper path still does not exist after repair: %s" % [_current_scene_pick_field, assigned_path])
			_append_log(str(repair_result.get("message", "Browse-select the original .glb/.gltf again so it can be imported and wrapped.")))
			_run_validation()
			return

	_model.set_value(_current_scene_pick_field, assigned_path)
	if _field_controls.has(_current_scene_pick_field):
		var edit = _field_controls[_current_scene_pick_field] as LineEdit
		edit.text = assigned_path
	_refresh_path_label()
	_append_log("Assigned scene path for %s: %s" % [_current_scene_pick_field, assigned_path])
	_append_log(str(wrapper_result.get("message", "Theme piece prepared.")))
	var dependency_notes: Array = Array(wrapper_result.get("dependency_notes", []))
	for dependency_note in dependency_notes:
		_append_log(str(dependency_note))
	_run_validation()

func _save_to_absolute_path(absolute_path: String) -> void:
	var result: Dictionary = _io.save_theme_json(absolute_path, _model.to_dictionary())
	if not bool(result.get("ok", false)):
		_append_log("Save failed: %s" % str(result.get("error", "Unknown error.")))
		return
	_model.mark_saved(absolute_path)
	_refresh_path_label()
	_append_log("Save completed. Theme file: %s" % _io.to_preferred_display_path(ProjectSettings.globalize_path("res://"), absolute_path))

func _run_validation(reason: String = "auto") -> Dictionary:
	_repair_missing_wrappers_before_validation()
	var project_root: String = ProjectSettings.globalize_path("res://")
	var report: Dictionary = _validation_service.validate_theme_data(
		_model.to_dictionary(),
		project_root
	)
	_validation_run_index += 1
	var report_text: String = _validation_service.build_report_text(report)
	var stamped_report_text: String = _build_stamped_validation_report(report_text, reason, project_root, report)
	_set_validation_report_text(stamped_report_text)
	return report

func _build_stamped_validation_report(report_text: String, reason: String, project_root: String, report: Dictionary) -> String:
	var status_text: String = "PASS"
	if not bool(report.get("is_valid", false)):
		status_text = "FAIL"
	var current_file_text: String = "<unsaved>"
	if not _model.current_file_path.is_empty():
		current_file_text = _io.to_preferred_display_path(project_root, _model.current_file_path)
	return "\n".join([
		"Validation Refresh: #%s" % _validation_run_index,
		"Validation Status: %s" % status_text,
		"Reason: %s" % reason,
		"Current Theme File: %s" % current_file_text,
		"",
		report_text,
	])

func _set_validation_report_text(report_text: String) -> void:
	if validation_report == null:
		return
	validation_report.clear()
	validation_report.text = report_text
	validation_report.set_caret_line(0)
	validation_report.set_caret_column(0)
	validation_report.scroll_vertical = 0
	validation_report.queue_redraw()

func _append_validation_summary(report: Dictionary) -> void:
	var errors: Array = Array(report.get("errors", []))
	var warnings: Array = Array(report.get("warnings", []))
	var info: Array = Array(report.get("info", []))
	var result_text: String = "PASS"
	if not bool(report.get("is_valid", false)):
		result_text = "FAIL"
	_append_log("Validation report refreshed #%s: %s, %s error(s), %s warning(s), %s info item(s)." % [_validation_run_index, result_text, errors.size(), warnings.size(), info.size()])

func _repair_missing_wrappers_before_validation() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	for field_name in SCENE_PATH_FIELDS:
		var path_value: String = str(_model.get_value(field_name, "")).strip_edges()
		if path_value.is_empty():
			continue
		var repair_result: Dictionary = _model_wrapper_builder.repair_missing_wrapper_scene_path(project_root, path_value, field_name)
		if not bool(repair_result.get("ok", false)):
			_append_log("Wrapper repair failed for %s: %s" % [field_name, str(repair_result.get("error", "Unknown error."))])
			continue
		if bool(repair_result.get("repaired", false)):
			_append_log("Repaired missing wrapper for %s: %s" % [field_name, path_value])

func _append_log(message: String) -> void:
	if status_log.text.is_empty():
		status_log.text = message
	else:
		status_log.text += "\n" + message
