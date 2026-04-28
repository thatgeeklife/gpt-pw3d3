extends RefCounted

const CHUNK_TILE_RENDERER_SCENE := preload("res://scenes/generated/ChunkTileRenderer.tscn")
const ROOM_FLOOR_LAYOUT_BUILDER_SCRIPT := preload("res://systems/level_runtime/RoomFloorLayoutBuilder.gd")
const ROOM_WALL_LAYOUT_BUILDER_SCRIPT := preload("res://systems/level_runtime/RoomWallLayoutBuilder.gd")
const THEME_PIECE_VARIANT_SCRIPT := preload("res://systems/level_runtime/ThemePieceVariant.gd")
const THEME_VARIANT_RESOLVER_SCRIPT := preload("res://systems/level_runtime/ThemeVariantResolver.gd")

const DEFAULT_BORDER_TILES := 5
const DEFAULT_CELL_WORLD_SIZE := 2.0
const DEFAULT_AUTHORED_WALL_HEIGHT := 5.0
const DEFAULT_AUTHORED_WALL_THICKNESS := 0.5
const BASE_FLOOR_THICKNESS := 0.20
const OUTER_FLOOR_TILE_THICKNESS := 0.025
const EDGE_FLOOR_TILE_THICKNESS := 0.03
const PLAY_FLOOR_TILE_THICKNESS := 0.04
const OUTER_FLOOR_TILE_Y := 0.0125
const EDGE_FLOOR_TILE_Y := 0.015
const PLAY_FLOOR_TILE_Y := 0.02
const FLOOR_TILE_INSET_RATIO := 0.94
const MAX_AUTHORED_FLOOR_SCENE_INSTANCES := 1600

func generate_level(
	level_definition: Resource,
	theme: Resource,
	_completed_pixel_ids: Dictionary = {},
	border_tiles: int = DEFAULT_BORDER_TILES,
	runtime_data: Resource = null
) -> Node3D:
	if level_definition == null:
		push_error("LevelGenerator: level definition was null.")
		return null

	if theme == null:
		push_error("LevelGenerator: theme was null.")
		return null

	if runtime_data == null:
		push_error("LevelGenerator: runtime data was null.")
		return null

	var bounds: Dictionary = _compute_bounds(level_definition)
	if not bool(bounds.get("has_pixels", false)):
		push_error("LevelGenerator: level definition contains no visible pixels.")
		return null

	var room_width_cells: int = int(bounds.get("occupied_width", 0)) + (border_tiles * 2)
	var room_depth_cells: int = int(bounds.get("occupied_height", 0)) + (border_tiles * 2)

	var generated_root := Node3D.new()
	generated_root.name = "GeneratedLevelRoot"
	generated_root.set_meta("level_id", str(level_definition.level_id))
	generated_root.set_meta("theme_id", str(theme.theme_id))
	generated_root.set_meta("border_tiles", border_tiles)
	generated_root.set_meta("bounds", bounds)
	generated_root.set_meta("room_width_cells", room_width_cells)
	generated_root.set_meta("room_depth_cells", room_depth_cells)
	generated_root.set_meta("tile_renderer_mode", "chunk_multimesh")
	generated_root.set_meta("floor_renderer_mode", "authored_or_zoned_multimesh")
	generated_root.set_meta("wall_renderer_mode", "authored_or_modular_weighted_segments")
	generated_root.set_meta("cell_world_size", _get_cell_world_size(theme))
	generated_root.set_meta("authored_scene_pack_id", str(theme.authored_scene_pack_id))

	var floor_root := Node3D.new()
	floor_root.name = "FloorRoot"
	generated_root.add_child(floor_root)

	var wall_root := Node3D.new()
	wall_root.name = "WallRoot"
	generated_root.add_child(wall_root)

	var tile_root := Node3D.new()
	tile_root.name = "TileRoot"
	generated_root.add_child(tile_root)

	var effects_root := Node3D.new()
	effects_root.name = "EffectsRoot"
	generated_root.add_child(effects_root)

	var lighting_root := Node3D.new()
	lighting_root.name = "LightingRoot"
	generated_root.add_child(lighting_root)

	_build_floor(floor_root, bounds, theme, border_tiles)
	_build_walls(wall_root, bounds, theme, border_tiles, str(level_definition.level_id))
	_build_chunk_renderers(tile_root, runtime_data)
	_build_default_lighting(lighting_root)

	return generated_root

func clear_generated_level(generated_root: Node) -> void:
	if generated_root == null:
		return
	generated_root.queue_free()

func get_tile_by_pixel_id(_generated_root: Node, _pixel_id: int) -> Node:
	return null

func get_tile_at_grid(_generated_root: Node, _grid_pos: Vector2i) -> Node:
	return null

func get_effects_root(generated_root: Node) -> Node3D:
	if generated_root == null:
		return null
	return generated_root.get_node_or_null("EffectsRoot") as Node3D

func get_chunk_root(generated_root: Node, chunk_index: int) -> Node3D:
	if generated_root == null:
		return null
	var tile_root: Node = generated_root.get_node_or_null("TileRoot")
	if tile_root == null:
		return null
	return tile_root.get_node_or_null("Chunk_%s" % chunk_index) as Node3D

func set_chunk_visible(generated_root: Node, chunk_index: int, is_visible: bool) -> void:
	var chunk_root: Node3D = get_chunk_root(generated_root, chunk_index)
	if chunk_root == null:
		return
	chunk_root.visible = is_visible

func refresh_chunk_runtime_state(generated_root: Node, runtime_data: Resource, chunk_index: int) -> void:
	if generated_root == null or runtime_data == null:
		return

	var chunk_root: Node3D = get_chunk_root(generated_root, chunk_index)
	if chunk_root == null:
		return

	var renderer: Node = chunk_root.get_node_or_null("ChunkTileRenderer")
	if renderer == null:
		return
	if renderer.has_method("rebuild_from_runtime_data"):
		renderer.rebuild_from_runtime_data(runtime_data, runtime_data.get_chunk_tile_indices(chunk_index))

func grid_to_local_position(
	grid_pos: Vector2i,
	bounds: Dictionary,
	border_tiles: int = DEFAULT_BORDER_TILES
) -> Vector3:
	var room_width_cells: int = int(bounds.get("occupied_width", 0)) + (border_tiles * 2)
	var room_depth_cells: int = int(bounds.get("occupied_height", 0)) + (border_tiles * 2)

	var cell_x: int = (grid_pos.x - int(bounds.get("min_x", 0))) + border_tiles
	var cell_z: int = (grid_pos.y - int(bounds.get("min_y", 0))) + border_tiles

	var room_center_x: float = (float(room_width_cells) - 1.0) * 0.5
	var room_center_z: float = (float(room_depth_cells) - 1.0) * 0.5
	var cell_world_size: float = DEFAULT_CELL_WORLD_SIZE

	return Vector3(
		(float(cell_x) - room_center_x) * cell_world_size,
		0.0,
		(float(cell_z) - room_center_z) * cell_world_size
	)

func _compute_bounds(level_definition: Resource) -> Dictionary:
	var has_pixels: bool = false
	var min_x: int = 0
	var min_y: int = 0
	var max_x: int = 0
	var max_y: int = 0

	for pixel_resource in level_definition.pixels:
		if pixel_resource == null:
			continue

		var grid_pos: Vector2i = pixel_resource.grid_pos
		if not has_pixels:
			has_pixels = true
			min_x = grid_pos.x
			min_y = grid_pos.y
			max_x = grid_pos.x
			max_y = grid_pos.y
		else:
			min_x = mini(min_x, grid_pos.x)
			min_y = mini(min_y, grid_pos.y)
			max_x = maxi(max_x, grid_pos.x)
			max_y = maxi(max_y, grid_pos.y)

	if not has_pixels:
		return {
			"has_pixels": false,
		}

	return {
		"has_pixels": true,
		"min_x": min_x,
		"min_y": min_y,
		"max_x": max_x,
		"max_y": max_y,
		"occupied_width": (max_x - min_x) + 1,
		"occupied_height": (max_y - min_y) + 1,
	}

func _build_floor(floor_root: Node3D, bounds: Dictionary, theme: Resource, border_tiles: int) -> void:
	var cell_world_size: float = _get_cell_world_size(theme)
	var floor_layout_builder = ROOM_FLOOR_LAYOUT_BUILDER_SCRIPT.new()
	var floor_layout: Dictionary = floor_layout_builder.build_layout(bounds, border_tiles, cell_world_size)

	var room_width_cells: int = int(floor_layout.get("room_width_cells", 0))
	var room_depth_cells: int = int(floor_layout.get("room_depth_cells", 0))
	var room_world_width: float = float(room_width_cells) * cell_world_size
	var room_world_depth: float = float(room_depth_cells) * cell_world_size

	_create_floor_base(floor_root, room_world_width, room_world_depth, theme.border_floor_color)

	_build_floor_zone_from_theme_or_fallback(
		floor_root,
		"outer",
		"OuterFloorTiles",
		Array(floor_layout.get("outer_positions", [])),
		cell_world_size,
		OUTER_FLOOR_TILE_THICKNESS,
		OUTER_FLOOR_TILE_Y,
		theme.border_floor_color,
		0.92,
		theme
	)
	_build_floor_zone_from_theme_or_fallback(
		floor_root,
		"edge",
		"EdgeFloorTiles",
		Array(floor_layout.get("edge_positions", [])),
		cell_world_size,
		EDGE_FLOOR_TILE_THICKNESS,
		EDGE_FLOOR_TILE_Y,
		theme.edge_floor_color,
		0.94,
		theme
	)
	_build_floor_zone_from_theme_or_fallback(
		floor_root,
		"play",
		"PlayFloorTiles",
		Array(floor_layout.get("play_positions", [])),
		cell_world_size,
		PLAY_FLOOR_TILE_THICKNESS,
		PLAY_FLOOR_TILE_Y,
		theme.floor_color,
		0.96,
		theme
	)

func _build_floor_zone_from_theme_or_fallback(
	floor_root: Node3D,
	zone_name: String,
	node_name: String,
	positions: Array,
	cell_world_size: float,
	thickness: float,
	center_y: float,
	color_value: Color,
	roughness_value: float,
	theme: Resource
) -> void:
	var scene_path: String = ""
	if theme != null and theme.has_method("get_floor_scene_path_for_zone"):
		scene_path = str(theme.get_floor_scene_path_for_zone(zone_name))

	if not scene_path.is_empty() and ResourceLoader.exists(scene_path) and positions.size() <= MAX_AUTHORED_FLOOR_SCENE_INSTANCES:
		_create_floor_scene_instances(floor_root, node_name, scene_path, positions, cell_world_size, color_value, theme)
		return

	_create_floor_zone_multimesh(
		floor_root,
		node_name,
		positions,
		cell_world_size,
		thickness,
		center_y,
		color_value,
		roughness_value
	)

func _create_floor_base(floor_root: Node3D, room_world_width: float, room_world_depth: float, color_value: Color) -> void:
	var base_floor := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(room_world_width, BASE_FLOOR_THICKNESS, room_world_depth)
	base_floor.mesh = base_mesh
	base_floor.position = Vector3(0.0, -(BASE_FLOOR_THICKNESS * 0.5), 0.0)
	base_floor.material_override = _make_color_material(color_value.darkened(0.06), 0.90)
	floor_root.add_child(base_floor)

	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(room_world_width, BASE_FLOOR_THICKNESS, room_world_depth)
	floor_collision.shape = floor_shape
	floor_body.position = Vector3(0.0, -(BASE_FLOOR_THICKNESS * 0.5), 0.0)
	floor_body.add_child(floor_collision)
	floor_root.add_child(floor_body)

func _create_floor_zone_multimesh(
	floor_root: Node3D,
	node_name: String,
	positions: Array,
	cell_world_size: float,
	thickness: float,
	center_y: float,
	color_value: Color,
	roughness_value: float
) -> void:
	if positions.is_empty():
		return

	var zone_instance := MultiMeshInstance3D.new()
	zone_instance.name = node_name
	floor_root.add_child(zone_instance)

	var zone_mesh := BoxMesh.new()
	zone_mesh.size = Vector3(cell_world_size * FLOOR_TILE_INSET_RATIO, thickness, cell_world_size * FLOOR_TILE_INSET_RATIO)

	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = false
	multi_mesh.use_custom_data = false
	multi_mesh.mesh = zone_mesh
	multi_mesh.instance_count = positions.size()
	zone_instance.multimesh = multi_mesh
	zone_instance.material_override = _make_color_material(color_value, roughness_value)

	for index in range(positions.size()):
		var base_position: Vector3 = positions[index]
		var final_position := Vector3(base_position.x, center_y, base_position.z)
		multi_mesh.set_instance_transform(index, Transform3D(Basis(), final_position))

func _create_floor_scene_instances(
	floor_root: Node3D,
	node_name: String,
	scene_path: String,
	positions: Array,
	cell_world_size: float,
	color_value: Color,
	theme: Resource
) -> void:
	if positions.is_empty():
		return

	var packed_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if packed_scene == null:
		return

	var zone_root := Node3D.new()
	zone_root.name = node_name
	floor_root.add_child(zone_root)

	var expected_size: float = max(float(theme.expected_floor_piece_world_size), 0.001)
	var uniform_scale: float = cell_world_size / expected_size

	for index in range(positions.size()):
		var instance: Node3D = packed_scene.instantiate() as Node3D
		if instance == null:
			continue
		instance.name = "%s_%s" % [node_name, index]
		instance.position = positions[index]
		instance.scale = Vector3(uniform_scale, 1.0, uniform_scale)
		_apply_material_override_recursive(instance, color_value, 0.94)
		zone_root.add_child(instance)

func _build_walls(wall_root: Node3D, bounds: Dictionary, theme: Resource, border_tiles: int, level_id: String) -> void:
	var cell_world_size: float = _get_cell_world_size(theme)
	var wall_layout_builder = ROOM_WALL_LAYOUT_BUILDER_SCRIPT.new()
	var wall_layout: Dictionary = wall_layout_builder.build_layout(bounds, border_tiles, cell_world_size, max(float(theme.wall_thickness), 0.1))
	var perimeter_cells: int = int(wall_layout.get("perimeter_cells", 0))

	var straight_variants: Array = _build_straight_wall_variants(theme)
	var corner_variants: Array = _build_corner_wall_variants(theme)
	var resolver = THEME_VARIANT_RESOLVER_SCRIPT.new()

	var recent_by_run: Dictionary = {}
	for slot_variant in Array(wall_layout.get("straight_slots", [])):
		var slot: Dictionary = slot_variant
		var run_id: String = str(slot.get("run_id", ""))
		if not recent_by_run.has(run_id):
			recent_by_run[run_id] = []

		var recent_variant_ids: Array = recent_by_run[run_id]
		var selected_variant: Resource = resolver.select_variant(
			straight_variants,
			level_id,
			str(theme.theme_id),
			int(slot.get("slot_index", 0)),
			str(slot.get("slot_category", "")),
			perimeter_cells,
			recent_variant_ids
		)
		if selected_variant == null:
			continue

		_create_modular_wall_segment(wall_root, slot, selected_variant, theme)
		recent_variant_ids.append(str(selected_variant.variant_id))
		if recent_variant_ids.size() > 2:
			recent_variant_ids.pop_front()
		recent_by_run[run_id] = recent_variant_ids

	for slot_variant in Array(wall_layout.get("corner_slots", [])):
		var slot: Dictionary = slot_variant
		var selected_corner: Resource = resolver.select_variant(
			corner_variants,
			level_id,
			str(theme.theme_id),
			int(slot.get("slot_index", 0)),
			str(slot.get("slot_category", "")),
			perimeter_cells,
			[]
		)
		if selected_corner == null:
			continue
		_create_corner_post(wall_root, slot, selected_corner, theme)

func _build_straight_wall_variants(theme: Resource) -> Array:
	var variants: Array = []

	var common_variant: Resource = THEME_PIECE_VARIANT_SCRIPT.new()
	common_variant.configure(
		"straight_common",
		int(theme.wall_variant_weight_common),
		0,
		999999,
		1.00,
		1.00,
		1.00,
		0.00,
		theme.wall_color,
		0.95,
		str(theme.straight_wall_scene_a_path)
	)
	variants.append(common_variant)

	var inset_variant: Resource = THEME_PIECE_VARIANT_SCRIPT.new()
	inset_variant.configure(
		"straight_inset",
		int(theme.wall_variant_weight_inset),
		0,
		999999,
		0.86,
		0.94,
		0.88,
		0.22,
		theme.wall_color.lightened(0.12),
		0.90,
		str(theme.straight_wall_scene_b_path)
	)
	variants.append(inset_variant)

	var buttress_variant: Resource = THEME_PIECE_VARIANT_SCRIPT.new()
	buttress_variant.configure(
		"straight_buttress",
		int(theme.wall_variant_weight_buttress),
		int(theme.wall_small_room_disable_buttress_under_perimeter),
		999999,
		0.74,
		1.12,
		1.42,
		0.16,
		theme.wall_color.darkened(0.10),
		0.96,
		str(theme.straight_wall_scene_c_path)
	)
	variants.append(buttress_variant)

	return variants

func _build_corner_wall_variants(theme: Resource) -> Array:
	var variants: Array = []

	var common_corner: Resource = THEME_PIECE_VARIANT_SCRIPT.new()
	common_corner.configure(
		"corner_post_common",
		80,
		0,
		999999,
		1.00,
		float(theme.wall_corner_post_scale),
		1.00,
		0.12,
		theme.wall_color.lightened(0.10),
		0.94,
		str(theme.corner_post_scene_a_path)
	)
	variants.append(common_corner)

	var accent_corner: Resource = THEME_PIECE_VARIANT_SCRIPT.new()
	accent_corner.configure(
		"corner_post_accent",
		20,
		28,
		999999,
		1.14,
		float(theme.wall_corner_post_scale) * 1.06,
		1.18,
		0.18,
		theme.wall_color.darkened(0.10),
		0.96,
		str(theme.corner_post_scene_b_path)
	)
	variants.append(accent_corner)

	return variants

func _create_modular_wall_segment(wall_root: Node3D, slot: Dictionary, variant: Resource, theme: Resource) -> void:
	var base_segment_length: float = float(slot.get("segment_length", _get_cell_world_size(theme)))
	var wall_height: float = max(float(theme.wall_height), 1.0) * float(variant.height_scale)
	var wall_thickness: float = max(float(theme.wall_thickness), 0.1) * float(variant.thickness_scale)
	var local_position: Vector3 = slot.get("world_position", Vector3.ZERO)
	var axis: String = str(slot.get("axis", "x"))

	var size: Vector3 = Vector3.ZERO
	if axis == "x":
		size = Vector3(base_segment_length * float(variant.length_scale), wall_height, wall_thickness)
	else:
		size = Vector3(wall_thickness, wall_height, base_segment_length * float(variant.length_scale))

	var final_color: Color = theme.wall_color.lerp(Color(variant.color_target), clamp(float(variant.color_mix), 0.0, 1.0))

	if variant.has_scene_path() and ResourceLoader.exists(str(variant.scene_path)):
		_instantiate_authored_wall_scene(
			wall_root,
			"WallSegment_%s" % str(slot.get("slot_index", 0)),
			str(variant.scene_path),
			size,
			Vector3(local_position.x, 0.0, local_position.z),
			axis,
			final_color,
			float(variant.roughness),
			theme
		)
		return

	_create_wall_mesh_and_collision(
		wall_root,
		"WallSegment_%s" % str(slot.get("slot_index", 0)),
		size,
		Vector3(local_position.x, wall_height * 0.5, local_position.z),
		final_color,
		float(variant.roughness)
	)

func _create_corner_post(wall_root: Node3D, slot: Dictionary, variant: Resource, theme: Resource) -> void:
	var wall_thickness: float = max(float(theme.wall_thickness), 0.1)
	var wall_height: float = max(float(theme.wall_height), 1.0) * float(variant.height_scale)
	var width: float = wall_thickness * 1.65 * float(variant.length_scale)
	var depth: float = wall_thickness * 1.65 * float(variant.thickness_scale)
	var local_position: Vector3 = slot.get("world_position", Vector3.ZERO)
	var final_color: Color = theme.wall_color.lerp(Color(variant.color_target), clamp(float(variant.color_mix), 0.0, 1.0))
	var target_size: Vector3 = Vector3(width, wall_height, depth)

	if variant.has_scene_path() and ResourceLoader.exists(str(variant.scene_path)):
		_instantiate_authored_wall_scene(
			wall_root,
			"CornerPost_%s" % str(slot.get("slot_index", 0)),
			str(variant.scene_path),
			target_size,
			Vector3(local_position.x, 0.0, local_position.z),
			"corner",
			final_color,
			float(variant.roughness),
			theme
		)
		return

	_create_wall_mesh_and_collision(
		wall_root,
		"CornerPost_%s" % str(slot.get("slot_index", 0)),
		target_size,
		Vector3(local_position.x, wall_height * 0.5, local_position.z),
		final_color,
		float(variant.roughness)
	)

func _instantiate_authored_wall_scene(
	wall_root: Node3D,
	node_name: String,
	scene_path: String,
	target_size: Vector3,
	base_position: Vector3,
	axis: String,
	color_value: Color,
	roughness_value: float,
	theme: Resource
) -> void:
	var packed_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if packed_scene == null:
		_create_wall_mesh_and_collision(
			wall_root,
			node_name,
			target_size,
			Vector3(base_position.x, target_size.y * 0.5, base_position.z),
			color_value,
			roughness_value
		)
		return

	var instance: Node3D = packed_scene.instantiate() as Node3D
	if instance == null:
		_create_wall_mesh_and_collision(
			wall_root,
			node_name,
			target_size,
			Vector3(base_position.x, target_size.y * 0.5, base_position.z),
			color_value,
			roughness_value
		)
		return

	instance.name = node_name
	instance.position = base_position
	if axis == "z":
		instance.rotate_y(deg_to_rad(90.0))
	elif axis == "corner":
		instance.rotate_y(0.0)

	var expected_length: float = max(float(theme.expected_wall_segment_world_length), 0.001)
	var expected_height: float = DEFAULT_AUTHORED_WALL_HEIGHT
	var expected_thickness: float = DEFAULT_AUTHORED_WALL_THICKNESS
	instance.scale = Vector3(
		target_size.x / expected_length,
		target_size.y / expected_height,
		target_size.z / expected_thickness
	)
	_apply_material_override_recursive(instance, color_value, roughness_value)
	wall_root.add_child(instance)

	var collision_body := StaticBody3D.new()
	collision_body.name = "%sBody" % node_name
	collision_body.position = Vector3(base_position.x, target_size.y * 0.5, base_position.z)
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = target_size
	collision_shape.shape = box_shape
	collision_body.add_child(collision_shape)
	wall_root.add_child(collision_body)

func _apply_material_override_recursive(root_node: Node, color_value: Color, roughness_value: float) -> void:
	if root_node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = root_node
		mesh_instance.material_override = _make_color_material(color_value, roughness_value)
	for child in root_node.get_children():
		_apply_material_override_recursive(child, color_value, roughness_value)

func _create_wall_mesh_and_collision(
	wall_root: Node3D,
	node_name: String,
	size: Vector3,
	local_position: Vector3,
	color_value: Color,
	roughness_value: float
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = size
	mesh_instance.mesh = wall_mesh
	mesh_instance.position = local_position
	mesh_instance.material_override = _make_color_material(color_value, roughness_value)
	wall_root.add_child(mesh_instance)

	var wall_body := StaticBody3D.new()
	wall_body.name = "%sBody" % node_name
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = size
	wall_collision.shape = wall_shape
	wall_body.position = local_position
	wall_body.add_child(wall_collision)
	wall_root.add_child(wall_body)

func _build_chunk_renderers(tile_root: Node3D, runtime_data: Resource) -> void:
	for chunk_index in range(runtime_data.get_chunk_count()):
		var chunk_root := Node3D.new()
		chunk_root.name = "Chunk_%s" % chunk_index
		tile_root.add_child(chunk_root)

		var renderer = CHUNK_TILE_RENDERER_SCENE.instantiate()
		renderer.name = "ChunkTileRenderer"
		chunk_root.add_child(renderer)

		if renderer.has_method("configure"):
			renderer.configure(chunk_index)
		if renderer.has_method("rebuild_from_runtime_data"):
			renderer.rebuild_from_runtime_data(runtime_data, runtime_data.get_chunk_tile_indices(chunk_index))

func _build_default_lighting(lighting_root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 2.0
	lighting_root.add_child(sun)

func _get_cell_world_size(theme: Resource) -> float:
	if theme != null:
		var value = theme.get("cell_world_size")
		if value != null:
			return max(float(value), 0.5)
	return DEFAULT_CELL_WORLD_SIZE

func _make_color_material(color_value: Color, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color_value
	material.roughness = roughness_value
	material.metallic = 0.0
	return material
