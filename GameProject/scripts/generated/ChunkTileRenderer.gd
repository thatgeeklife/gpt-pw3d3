extends Node3D

const LEVEL_RENDER_RESOURCES := preload("res://systems/level_runtime/LevelRenderResources.gd")
const TILE_HEIGHT := 0.25

var chunk_index: int = -1

var incomplete_tiles: MultiMeshInstance3D = null
var completed_tiles: MultiMeshInstance3D = null
var completed_orb_shells: MultiMeshInstance3D = null
var completed_orb_cores: MultiMeshInstance3D = null
var completed_tile_buckets_root: Node3D = null
var completed_orb_shell_buckets_root: Node3D = null
var completed_orb_core_buckets_root: Node3D = null

func _ready() -> void:
	_resolve_nodes()
	_apply_materials()

func configure(new_chunk_index: int) -> void:
	chunk_index = new_chunk_index
	_resolve_nodes()
	_apply_materials()

func set_renderer_visible(renderer_visible: bool) -> void:
	visible = renderer_visible

func rebuild_from_runtime_data(runtime_data: Resource, tile_indices: PackedInt32Array) -> void:
	_resolve_nodes()
	_apply_materials()

	if runtime_data == null:
		_clear_all_multimeshes()
		return

	var incomplete_tile_indices: Array[int] = []
	var completed_tiles_by_palette: Dictionary = {}

	for tile_index_variant in tile_indices:
		var tile_index: int = int(tile_index_variant)
		if runtime_data.is_tile_completed_by_index(tile_index):
			var palette_index: int = runtime_data.get_tile_palette_index(tile_index)
			if not completed_tiles_by_palette.has(palette_index):
				completed_tiles_by_palette[palette_index] = []
			completed_tiles_by_palette[palette_index].append(tile_index)
		else:
			incomplete_tile_indices.append(tile_index)

	_rebuild_incomplete_multimesh(runtime_data, incomplete_tile_indices)
	_rebuild_completed_palette_buckets(runtime_data, completed_tiles_by_palette)

func _resolve_nodes() -> void:
	if incomplete_tiles == null:
		incomplete_tiles = get_node_or_null("IncompleteTiles") as MultiMeshInstance3D
	if completed_tiles == null:
		completed_tiles = get_node_or_null("CompletedTiles") as MultiMeshInstance3D
	if completed_orb_shells == null:
		completed_orb_shells = get_node_or_null("CompletedOrbShells") as MultiMeshInstance3D
	if completed_orb_cores == null:
		completed_orb_cores = get_node_or_null("CompletedOrbCores") as MultiMeshInstance3D
	if completed_tile_buckets_root == null:
		completed_tile_buckets_root = _ensure_bucket_root("CompletedTileBuckets")
	if completed_orb_shell_buckets_root == null:
		completed_orb_shell_buckets_root = _ensure_bucket_root("CompletedOrbShellBuckets")
	if completed_orb_core_buckets_root == null:
		completed_orb_core_buckets_root = _ensure_bucket_root("CompletedOrbCoreBuckets")

func _ensure_bucket_root(root_name: String) -> Node3D:
	var existing := get_node_or_null(root_name) as Node3D
	if existing != null:
		return existing
	var node := Node3D.new()
	node.name = root_name
	add_child(node)
	return node

func _apply_materials() -> void:
	_resolve_nodes()
	if incomplete_tiles != null:
		incomplete_tiles.material_override = LEVEL_RENDER_RESOURCES.get_incomplete_tile_material()

func _clear_all_multimeshes() -> void:
	_clear_multimesh(incomplete_tiles, LEVEL_RENDER_RESOURCES.get_tile_mesh(TILE_HEIGHT))
	_hide_legacy_orb_multimeshes()
	_clear_bucket_children(completed_tile_buckets_root)
	_clear_bucket_children(completed_orb_shell_buckets_root)
	_clear_bucket_children(completed_orb_core_buckets_root)

func _hide_legacy_orb_multimeshes() -> void:
	if completed_orb_shells != null:
		completed_orb_shells.visible = false
		if completed_orb_shells.multimesh != null:
			completed_orb_shells.multimesh.instance_count = 0
	if completed_orb_cores != null:
		completed_orb_cores.visible = false
		if completed_orb_cores.multimesh != null:
			completed_orb_cores.multimesh.instance_count = 0
	if completed_tiles != null:
		completed_tiles.visible = false
		if completed_tiles.multimesh != null:
			completed_tiles.multimesh.instance_count = 0

func _clear_bucket_children(root_node: Node3D) -> void:
	if root_node == null:
		return
	for child in root_node.get_children():
		child.queue_free()

func _clear_multimesh(instance: MultiMeshInstance3D, mesh: Mesh) -> void:
	if instance == null:
		return
	var mm: MultiMesh = _ensure_multimesh(instance, mesh)
	mm.instance_count = 0
	instance.visible = false

func _rebuild_incomplete_multimesh(runtime_data: Resource, tile_indices: Array[int]) -> void:
	if incomplete_tiles == null:
		return

	var mm: MultiMesh = _ensure_multimesh(incomplete_tiles, LEVEL_RENDER_RESOURCES.get_tile_mesh(TILE_HEIGHT))
	mm.instance_count = tile_indices.size()
	incomplete_tiles.visible = tile_indices.size() > 0
	if tile_indices.is_empty():
		return

	for instance_index in range(tile_indices.size()):
		var tile_index: int = tile_indices[instance_index]
		var tile_local_pos: Vector3 = runtime_data.get_tile_local_position(tile_index)
		var transform_origin := Vector3(tile_local_pos.x, runtime_data.tile_surface_y - (TILE_HEIGHT * 0.5), tile_local_pos.z)
		mm.set_instance_transform(instance_index, Transform3D(Basis(), transform_origin))

func _rebuild_completed_palette_buckets(runtime_data: Resource, completed_tiles_by_palette: Dictionary) -> void:
	_clear_bucket_children(completed_tile_buckets_root)
	_clear_bucket_children(completed_orb_shell_buckets_root)
	_clear_bucket_children(completed_orb_core_buckets_root)
	_hide_legacy_orb_multimeshes()

	var palette_indices: Array = completed_tiles_by_palette.keys()
	palette_indices.sort()

	for palette_index_variant in palette_indices:
		var palette_index: int = int(palette_index_variant)
		var tile_indices: Array = completed_tiles_by_palette[palette_index]
		var source_color: Color = runtime_data.palette_colors[palette_index]

		_create_bucket_multimesh(
			completed_tile_buckets_root,
			"CompletedPalette_%s" % palette_index,
			LEVEL_RENDER_RESOURCES.get_completed_tile_material(source_color),
			LEVEL_RENDER_RESOURCES.get_tile_mesh(TILE_HEIGHT),
			tile_indices,
			runtime_data,
			Vector3(0.0, runtime_data.tile_surface_y - (TILE_HEIGHT * 0.5), 0.0)
		)

		_create_bucket_multimesh(
			completed_orb_shell_buckets_root,
			"CompletedOrbShell_%s" % palette_index,
			LEVEL_RENDER_RESOURCES.get_orb_shell_material(source_color),
			LEVEL_RENDER_RESOURCES.get_orb_shell_mesh(),
			tile_indices,
			runtime_data,
			Vector3(0.0, runtime_data.tile_surface_y, 0.0)
		)

		_create_bucket_multimesh(
			completed_orb_core_buckets_root,
			"CompletedOrbCore_%s" % palette_index,
			LEVEL_RENDER_RESOURCES.get_orb_core_material(source_color),
			LEVEL_RENDER_RESOURCES.get_orb_core_mesh(),
			tile_indices,
			runtime_data,
			Vector3(0.0, runtime_data.tile_surface_y, 0.0)
		)

func _create_bucket_multimesh(
	root_node: Node3D,
	node_name: String,
	material: Material,
	mesh: Mesh,
	tile_indices: Array,
	runtime_data: Resource,
	offset: Vector3
) -> void:
	if root_node == null:
		return
	if tile_indices.is_empty():
		return

	var bucket := MultiMeshInstance3D.new()
	bucket.name = node_name
	bucket.material_override = material
	root_node.add_child(bucket)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = mesh
	mm.instance_count = tile_indices.size()
	bucket.multimesh = mm

	for instance_index in range(tile_indices.size()):
		var tile_index: int = int(tile_indices[instance_index])
		var tile_local_pos: Vector3 = runtime_data.get_tile_local_position(tile_index)
		var transform_origin := Vector3(tile_local_pos.x + offset.x, offset.y, tile_local_pos.z + offset.z)
		mm.set_instance_transform(instance_index, Transform3D(Basis(), transform_origin))

func _ensure_multimesh(instance: MultiMeshInstance3D, mesh: Mesh) -> MultiMesh:
	if instance.multimesh == null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.use_custom_data = false
		mm.mesh = mesh
		instance.multimesh = mm
	else:
		instance.multimesh.mesh = mesh

	return instance.multimesh