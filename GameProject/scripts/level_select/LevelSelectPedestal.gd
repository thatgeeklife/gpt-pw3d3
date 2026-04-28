extends Node3D

@export var bound_level_id: String = ""
@export var fallback_level_key: String = ""
@export var missing_display_name: String = "Missing Level"

var level_key: String = ""
var level_id: String = ""
var level_name: String = ""
var preview_texture_path: String = ""
var is_selected: bool = false
var is_targeted: bool = false
var is_locked: bool = false
var is_completed: bool = false
var lock_reason: String = ""
var target_color: Color = Color(1.0, 0.85, 0.20, 1.0)
var is_missing_binding: bool = false

var base_mesh: MeshInstance3D = null
var label: Label3D = null
var status_label: Label3D = null
var preview_sprite: Sprite3D = null

func _ready() -> void:
	_resolve_nodes()
	_apply_visual_state()

func _resolve_nodes() -> void:
	if base_mesh == null:
		base_mesh = get_node_or_null("BaseMesh") as MeshInstance3D
	if label == null:
		label = get_node_or_null("LevelLabel") as Label3D
	if status_label == null:
		status_label = get_node_or_null("StatusLabel") as Label3D
	if preview_sprite == null:
		preview_sprite = get_node_or_null("PreviewSprite") as Sprite3D

func get_lookup_key() -> String:
	if not bound_level_id.is_empty():
		return bound_level_id
	if not fallback_level_key.is_empty():
		return fallback_level_key
	if not level_id.is_empty():
		return level_id
	return level_key

func bind_from_level_content_library(level_content_library: RefCounted, player_progress: Resource) -> Resource:
	var lookup_key: String = get_lookup_key()
	if lookup_key.is_empty() or level_content_library == null:
		configure_missing_binding(lookup_key)
		return null

	var entry: Resource = null
	if level_content_library.has_method("get_catalog_entry"):
		entry = level_content_library.get_catalog_entry(lookup_key, player_progress)

	if entry != null:
		configure_from_catalog_entry(entry)
		return entry

	configure_missing_binding(lookup_key)
	return null

func configure(new_level_key: String, new_level_name: String) -> void:
	level_key = new_level_key
	level_name = new_level_name
	is_missing_binding = false
	_resolve_nodes()
	if label != null:
		label.text = new_level_name
	_apply_visual_state()

func configure_from_catalog_entry(entry: Resource) -> void:
	if entry == null:
		return
	level_key = str(entry.level_key)
	level_id = str(entry.level_id)
	level_name = str(entry.level_name)
	preview_texture_path = str(entry.preview_texture_path)
	is_locked = not bool(entry.is_unlocked)
	is_completed = bool(entry.is_completed)
	lock_reason = str(entry.unlock_reason)
	is_missing_binding = false

	_resolve_nodes()
	if label != null:
		label.text = level_name
	if preview_sprite != null:
		preview_sprite.texture = _load_preview_texture(preview_texture_path)
	_apply_visual_state()

func configure_missing_binding(lookup_identifier: String) -> void:
	level_key = ""
	level_id = lookup_identifier
	level_name = missing_display_name if not lookup_identifier.is_empty() else "Unbound Pedestal"
	preview_texture_path = ""
	is_locked = true
	is_completed = false
	lock_reason = "Missing catalog entry for pedestal binding: %s" % lookup_identifier
	is_missing_binding = true

	_resolve_nodes()
	if label != null:
		label.text = level_name
	if preview_sprite != null:
		preview_sprite.texture = null
	_apply_visual_state()

func set_runtime_state(new_selected: bool, new_targeted: bool, new_target_color: Color, new_locked: bool, new_completed: bool, new_lock_reason: String) -> void:
	is_selected = new_selected
	is_targeted = new_targeted
	target_color = new_target_color
	is_locked = new_locked
	is_completed = new_completed
	lock_reason = new_lock_reason
	if new_lock_reason.begins_with("Missing catalog entry for pedestal binding:") or level_key.is_empty():
		is_missing_binding = true
	_apply_visual_state()

func set_targeted(is_on: bool, new_color: Color) -> void:
	is_targeted = is_on
	target_color = new_color
	_apply_visual_state()

func set_selected(is_on: bool) -> void:
	is_selected = is_on
	_apply_visual_state()

func _apply_visual_state() -> void:
	_resolve_nodes()
	if base_mesh == null:
		return

	var material := StandardMaterial3D.new()
	material.roughness = 0.60
	material.metallic = 0.0
	material.emission_enabled = true

	if is_missing_binding:
		material.albedo_color = Color(0.48, 0.14, 0.60, 1.0)
		material.emission = Color(0.72, 0.18, 0.92, 1.0)
		material.emission_energy_multiplier = 0.55
	elif is_locked:
		material.albedo_color = Color(0.28, 0.24, 0.24, 1.0)
		material.emission = Color(0.35, 0.10, 0.10, 1.0)
		material.emission_energy_multiplier = 0.45
	elif is_targeted:
		material.albedo_color = target_color.lightened(0.12)
		material.emission = target_color
		material.emission_energy_multiplier = 1.6
	elif is_selected:
		material.albedo_color = Color(0.92, 0.80, 0.46, 1.0)
		material.emission = Color(0.92, 0.80, 0.46, 1.0)
		material.emission_energy_multiplier = 0.95
	elif is_completed:
		material.albedo_color = Color(0.44, 0.70, 0.40, 1.0)
		material.emission = Color(0.22, 0.40, 0.18, 1.0)
		material.emission_energy_multiplier = 0.35
	else:
		material.albedo_color = Color(0.62, 0.55, 0.40, 1.0)
		material.emission = Color(0.20, 0.15, 0.10, 1.0)
		material.emission_energy_multiplier = 0.15

	base_mesh.material_override = material

	if label != null:
		label.modulate = Color(0.12, 0.08, 0.05, 1.0)
		label.outline_modulate = Color(0.96, 0.92, 0.80, 1.0)
		label.outline_size = 8

	if status_label != null:
		if is_missing_binding:
			status_label.text = "MISSING"
			status_label.modulate = Color(1.0, 0.45, 1.0, 1.0)
		elif is_locked:
			status_label.text = "LOCKED"
			status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
		elif is_completed:
			status_label.text = "COMPLETE"
			status_label.modulate = Color(0.60, 1.0, 0.55, 1.0)
		elif is_selected:
			status_label.text = "SELECTED"
			status_label.modulate = Color(1.0, 0.90, 0.35, 1.0)
		else:
			status_label.text = "AVAILABLE"
			status_label.modulate = Color(0.85, 0.82, 0.72, 1.0)

	if preview_sprite != null:
		if is_missing_binding:
			preview_sprite.modulate = Color(0.70, 0.45, 0.82, 1.0)
		elif is_locked:
			preview_sprite.modulate = Color(0.45, 0.45, 0.45, 1.0)
		else:
			preview_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _load_preview_texture(path_value: String) -> Texture2D:
	if path_value.is_empty():
		return null

	if path_value.begins_with("res://"):
		var resource = ResourceLoader.load(path_value)
		if resource is Texture2D:
			return resource
		if resource is Image:
			return ImageTexture.create_from_image(resource)

	var absolute_path: String = _resolve_path(path_value)
	if not FileAccess.file_exists(absolute_path):
		return null

	var image := Image.new()
	if image.load(absolute_path) != OK:
		return null

	return ImageTexture.create_from_image(image)

func _resolve_path(path_value: String) -> String:
	if path_value.begins_with("res://") or path_value.begins_with("user://"):
		return ProjectSettings.globalize_path(path_value)
	if path_value.begins_with("/") or path_value.contains(":/") or path_value.contains(":\\"):
		return path_value
	var project_root: String = ProjectSettings.globalize_path("res://")
	return project_root.path_join(path_value).simplify_path()
