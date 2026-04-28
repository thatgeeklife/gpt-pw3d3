extends PanelContainer

var _title_label: Label = null
var _preview_rect: TextureRect = null
var _state_label: Label = null
var _details_label: Label = null

func _ready() -> void:
	custom_minimum_size = Vector2(300.0, 300.0)
	visible = false

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_title_label)

	_preview_rect = TextureRect.new()
	_preview_rect.custom_minimum_size = Vector2(256.0, 128.0)
	_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_preview_rect)

	_state_label = Label.new()
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_state_label)

	_details_label = Label.new()
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_details_label)

func clear_display() -> void:
	if _title_label != null:
		_title_label.text = "No level selected"
	if _preview_rect != null:
		_preview_rect.texture = null
	if _state_label != null:
		_state_label.text = ""
	if _details_label != null:
		_details_label.text = ""
	visible = false

func update_from_catalog_entry(entry: Resource, is_selected: bool, is_targeted: bool) -> void:
	if entry == null:
		clear_display()
		return

	visible = true
	_title_label.text = str(entry.level_name)

	var parts: Array[String] = []
	if is_targeted:
		parts.append("Targeted")
	if is_selected:
		parts.append("Selected")
	if bool(entry.is_completed):
		parts.append("Completed")
	if bool(entry.is_unlocked):
		parts.append("Unlocked")
	else:
		parts.append("Locked")
	_state_label.text = " / ".join(parts)
	if not str(entry.unlock_reason).is_empty() and not bool(entry.is_unlocked):
		_state_label.text += "\n" + str(entry.unlock_reason)

	_details_label.text = "Theme: %s\nTiles: %s\nPalette: %s\nSize: %sx%s" % [
		str(entry.theme_id),
		str(int(entry.visible_pixel_count)),
		str(int(entry.palette_count)),
		str(int(entry.image_width)),
		str(int(entry.image_height)),
	]

	_preview_rect.texture = _load_preview_texture(str(entry.preview_texture_path))

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