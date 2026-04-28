extends Resource

## Central static registry of known generated levels and themes.

@export var levels: Array[Resource] = []
@export var themes: Array[Resource] = []

func add_level(level_definition: Resource) -> void:
	if level_definition == null:
		return
	levels.append(level_definition)

func add_theme(theme_resource: Resource) -> void:
	if theme_resource == null:
		return
	themes.append(theme_resource)

func get_level(level_id: String) -> Resource:
	for level_definition in levels:
		if level_definition == null:
			continue
		if str(level_definition.get("level_id")) == level_id:
			return level_definition
	return null

func get_theme(theme_id: String) -> Resource:
	for theme_resource in themes:
		if theme_resource == null:
			continue
		if str(theme_resource.get("theme_id")) == theme_id:
			return theme_resource
	return null

func has_level(level_id: String) -> bool:
	return get_level(level_id) != null

func has_theme(theme_id: String) -> bool:
	return get_theme(theme_id) != null

func get_level_ids() -> Array[String]:
	var ids: Array[String] = []
	for level_definition in levels:
		if level_definition == null:
			continue
		ids.append(str(level_definition.get("level_id")))
	return ids

func get_theme_ids() -> Array[String]:
	var ids: Array[String] = []
	for theme_resource in themes:
		if theme_resource == null:
			continue
		ids.append(str(theme_resource.get("theme_id")))
	return ids