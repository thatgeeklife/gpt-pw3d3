extends RefCounted

const TILE_WIDTH := 1.8
const INCOMPLETE_TILE_COLOR := Color(0.82, 0.74, 0.57, 1.0)
const ORB_SHELL_RADIUS := 0.62
const ORB_SHELL_HEIGHT := 1.24
const ORB_CORE_RADIUS := 0.36
const ORB_CORE_HEIGHT := 0.72

static var _tile_mesh_cache: Dictionary = {}
static var _highlight_forward_mesh: BoxMesh = null
static var _highlight_cross_mesh: BoxMesh = null
static var _orb_shell_mesh: SphereMesh = null
static var _orb_core_mesh: SphereMesh = null
static var _incomplete_tile_material: StandardMaterial3D = null
static var _completed_tile_material_cache: Dictionary = {}
static var _orb_shell_material_cache: Dictionary = {}
static var _orb_core_material_cache: Dictionary = {}

static func get_tile_mesh(tile_height: float) -> BoxMesh:
	var cache_key: String = "%.3f" % tile_height
	if _tile_mesh_cache.has(cache_key):
		return _tile_mesh_cache[cache_key]

	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(TILE_WIDTH, tile_height, TILE_WIDTH)
	_tile_mesh_cache[cache_key] = tile_mesh
	return tile_mesh

static func get_highlight_forward_mesh() -> BoxMesh:
	if _highlight_forward_mesh != null:
		return _highlight_forward_mesh

	_highlight_forward_mesh = BoxMesh.new()
	_highlight_forward_mesh.size = Vector3(0.42, 0.08, 1.96)
	return _highlight_forward_mesh

static func get_highlight_cross_mesh() -> BoxMesh:
	if _highlight_cross_mesh != null:
		return _highlight_cross_mesh

	_highlight_cross_mesh = BoxMesh.new()
	_highlight_cross_mesh.size = Vector3(1.96, 0.08, 0.42)
	return _highlight_cross_mesh

static func get_orb_shell_mesh() -> SphereMesh:
	if _orb_shell_mesh != null:
		return _orb_shell_mesh

	_orb_shell_mesh = SphereMesh.new()
	_orb_shell_mesh.radius = ORB_SHELL_RADIUS
	_orb_shell_mesh.height = ORB_SHELL_HEIGHT
	return _orb_shell_mesh

static func get_orb_core_mesh() -> SphereMesh:
	if _orb_core_mesh != null:
		return _orb_core_mesh

	_orb_core_mesh = SphereMesh.new()
	_orb_core_mesh.radius = ORB_CORE_RADIUS
	_orb_core_mesh.height = ORB_CORE_HEIGHT
	return _orb_core_mesh

static func get_incomplete_tile_color() -> Color:
	return INCOMPLETE_TILE_COLOR

static func get_incomplete_tile_material() -> StandardMaterial3D:
	if _incomplete_tile_material != null:
		return _incomplete_tile_material

	_incomplete_tile_material = StandardMaterial3D.new()
	_incomplete_tile_material.albedo_color = INCOMPLETE_TILE_COLOR
	_incomplete_tile_material.roughness = 0.98
	_incomplete_tile_material.metallic = 0.0
	_incomplete_tile_material.emission_enabled = false
	return _incomplete_tile_material

static func get_completed_tile_material(source_color: Color) -> StandardMaterial3D:
	var cache_key: String = _make_color_key(source_color)
	if _completed_tile_material_cache.has(cache_key):
		return _completed_tile_material_cache[cache_key]

	var material := StandardMaterial3D.new()
	material.albedo_color = source_color
	material.roughness = 0.98
	material.metallic = 0.0
	material.emission_enabled = false
	_completed_tile_material_cache[cache_key] = material
	return material

static func get_orb_shell_material(source_color: Color) -> StandardMaterial3D:
	var cache_key: String = _make_color_key(source_color)
	if _orb_shell_material_cache.has(cache_key):
		return _orb_shell_material_cache[cache_key]

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(source_color.r, source_color.g, source_color.b, 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.06
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = source_color
	material.emission_energy_multiplier = 1.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_orb_shell_material_cache[cache_key] = material
	return material

static func get_orb_core_material(source_color: Color) -> StandardMaterial3D:
	var cache_key: String = _make_color_key(source_color)
	if _orb_core_material_cache.has(cache_key):
		return _orb_core_material_cache[cache_key]

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(source_color.r, source_color.g, source_color.b, 0.96)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.18
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = source_color.lightened(0.08)
	material.emission_energy_multiplier = 1.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_orb_core_material_cache[cache_key] = material
	return material

static func _make_color_key(color_value: Color) -> String:
	return "%d_%d_%d_%d" % [
		int(round(color_value.r * 255.0)),
		int(round(color_value.g * 255.0)),
		int(round(color_value.b * 255.0)),
		int(round(color_value.a * 255.0)),
	]