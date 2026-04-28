extends RefCounted

const MANIFEST_VERSION := "M20"
const DEFAULT_MANIFEST_REL_PATH := "../SharedLevelContent/bake_manifest.json"

func load_manifest(absolute_manifest_path: String) -> Dictionary:
	if absolute_manifest_path.is_empty():
		return _make_empty_manifest()
	if not FileAccess.file_exists(absolute_manifest_path):
		return _make_empty_manifest()

	var file: FileAccess = FileAccess.open(absolute_manifest_path, FileAccess.READ)
	if file == null:
		return _make_empty_manifest()

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return _make_empty_manifest()

	var manifest: Dictionary = parsed
	if not manifest.has("levels"):
		manifest["levels"] = []
	if not manifest.has("manifest_version"):
		manifest["manifest_version"] = MANIFEST_VERSION
	return manifest

func save_manifest(manifest: Dictionary, absolute_manifest_path: String) -> Error:
	if absolute_manifest_path.is_empty():
		return ERR_INVALID_PARAMETER

	var output_dir: String = absolute_manifest_path.get_base_dir()
	if not output_dir.is_empty():
		var make_error: Error = DirAccess.make_dir_recursive_absolute(output_dir)
		if make_error != OK and make_error != ERR_ALREADY_EXISTS:
			return make_error

	var file: FileAccess = FileAccess.open(absolute_manifest_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(manifest, "\t"))
	file.flush()
	file.close()
	return OK

func upsert_level_entry(manifest: Dictionary, baked_definition: Resource, source_image_path: String, baked_tres_path: String, baked_json_path: String, baker_version: String) -> Dictionary:
	if not manifest.has("levels"):
		manifest["levels"] = []

	manifest["manifest_version"] = MANIFEST_VERSION
	manifest["last_baker_version"] = baker_version
	manifest["last_updated_utc"] = Time.get_datetime_string_from_system(true, true)

	var levels: Array = manifest["levels"]
	var entry: Dictionary = {
		"level_id": String(baked_definition.level_id),
		"level_name": String(baked_definition.level_name),
		"theme_id": String(baked_definition.theme_id),
		"preview_image_path": source_image_path,
		"source_image_path": source_image_path,
		"baked_tres_path": baked_tres_path,
		"baked_json_path": baked_json_path,
		"visible_pixel_count": int(baked_definition.visible_pixel_count),
		"palette_count": int(baked_definition.palette_colors.size()),
		"image_width": int(baked_definition.image_width),
		"image_height": int(baked_definition.image_height),
		"required_level_ids": baked_definition.required_level_ids.duplicate(),
		"required_dlc_id": String(baked_definition.required_dlc_id),
		"baker_version": baker_version,
		"bake_timestamp_utc": Time.get_datetime_string_from_system(true, true),
	}

	var replaced: bool = false
	for i in range(levels.size()):
		var existing = levels[i]
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		if String(existing.get("level_id", "")) == String(baked_definition.level_id):
			entry["sort_order"] = int(existing.get("sort_order", i + 1))
			levels[i] = entry
			replaced = true
			break

	if not replaced:
		entry["sort_order"] = levels.size() + 1
		levels.append(entry)

	levels.sort_custom(func(a, b):
		return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
	)

	manifest["levels"] = levels
	return manifest

func _make_empty_manifest() -> Dictionary:
	return {
		"manifest_version": MANIFEST_VERSION,
		"last_baker_version": "",
		"last_updated_utc": "",
		"levels": [],
	}