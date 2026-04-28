extends Node3D

const LEVEL_RENDER_RESOURCES := preload("res://systems/level_runtime/LevelRenderResources.gd")
const PARCHMENT_TILE: Color = Color(0.82, 0.74, 0.57, 1.0)
const TILE_SURFACE_Y: float = 0.10

var pixel_id: int = -1
var runtime_tile_index: int = -1
var grid_pos: Vector2i = Vector2i.ZERO
var source_color: Color = Color.WHITE
var muted_color: Color = PARCHMENT_TILE
var color_key: String = ""
var color_code: String = ""
var tile_height: float = 0.25
var is_completed: bool = false
var is_highlighted: bool = false
var highlight_color: Color = Color(1.0, 0.85, 0.20, 1.0)

var _base_orb_anchor_position: Vector3 = Vector3.ZERO
var _orb_time: float = 0.0
var _highlight_time: float = 0.0
var _orb_float_height: float = 0.045
var _orb_float_speed: float = 1.65
var _orb_pulse_speed: float = 2.0
var _orb_pulse_strength: float = 0.22
var _orb_base_emission_energy: float = 1.55
var _orb_base_scale: Vector3 = Vector3.ONE
var _code_label_forced_visible: bool = false
var _highlight_material: StandardMaterial3D = null
var _orb_shell_material: StandardMaterial3D = null
var _orb_core_material: StandardMaterial3D = null

var tile_base: MeshInstance3D = null
var highlight_mesh: MeshInstance3D = null
var highlight_cross_mesh: MeshInstance3D = null
var color_code_label: Label3D = null
var completion_orb_anchor: Node3D = null
var completion_orb_mesh: MeshInstance3D = null
var completion_orb_core_mesh: MeshInstance3D = null

func _ready() -> void:
	_ensure_node_refs()
	_base_orb_anchor_position = completion_orb_anchor.position
	_orb_base_scale = completion_orb_mesh.scale

func _ensure_node_refs() -> void:
	if tile_base == null:
		tile_base = get_node_or_null("TileBase") as MeshInstance3D
	if highlight_mesh == null:
		highlight_mesh = get_node_or_null("HighlightMesh") as MeshInstance3D
	if highlight_cross_mesh == null:
		highlight_cross_mesh = get_node_or_null("HighlightCrossMesh") as MeshInstance3D
	if color_code_label == null:
		color_code_label = get_node_or_null("ColorCodeLabel") as Label3D
	if completion_orb_anchor == null:
		completion_orb_anchor = get_node_or_null("CompletionOrbAnchor") as Node3D
	if completion_orb_mesh == null:
		completion_orb_mesh = get_node_or_null("CompletionOrbAnchor/CompletionOrbMesh") as MeshInstance3D
	if completion_orb_core_mesh == null:
		completion_orb_core_mesh = get_node_or_null("CompletionOrbAnchor/CompletionOrbCoreMesh") as MeshInstance3D

func _process(delta: float) -> void:
	if is_completed:
		_orb_time += delta
		var float_offset: float = sin(_orb_time * _orb_float_speed) * _orb_float_height
		completion_orb_anchor.position = _base_orb_anchor_position + Vector3(0.0, float_offset, 0.0)

		var pulse_wave: float = (sin(_orb_time * _orb_pulse_speed) + 1.0) * 0.5
		var pulse_amount: float = 1.0 + ((pulse_wave - 0.5) * _orb_pulse_strength)
		completion_orb_mesh.scale = _orb_base_scale * pulse_amount
		if completion_orb_core_mesh != null:
			completion_orb_core_mesh.scale = _orb_base_scale * (0.86 + ((pulse_wave - 0.5) * 0.10))

		if _orb_shell_material != null:
			_orb_shell_material.emission_energy_multiplier = _orb_base_emission_energy + (pulse_wave * 0.45)

		if _orb_core_material != null:
			_orb_core_material.emission_energy_multiplier = (_orb_base_emission_energy * 0.75) + (pulse_wave * 0.35)

	if is_highlighted and not is_completed:
		_highlight_time += delta
		_update_highlight_visual()

func setup_from_pixel(pixel_resource: Resource, _theme: Resource) -> void:
	_ensure_node_refs()
	if pixel_resource == null:
		return

	pixel_id = int(pixel_resource.pixel_id)
	grid_pos = pixel_resource.grid_pos
	source_color = pixel_resource.source_color
	color_key = str(pixel_resource.color_key)
	color_code = str(pixel_resource.color_code)
	muted_color = PARCHMENT_TILE

	_apply_geometry()
	_apply_completion_orb_visuals()
	_apply_highlight_visuals()
	_apply_color_code_label()
	set_incomplete()

func _apply_geometry() -> void:
	_ensure_node_refs()

	tile_base.mesh = LEVEL_RENDER_RESOURCES.get_tile_mesh(tile_height)
	tile_base.position = Vector3(0.0, TILE_SURFACE_Y - (tile_height * 0.5), 0.0)

	completion_orb_anchor.position = Vector3(0.0, TILE_SURFACE_Y, 0.0)
	_base_orb_anchor_position = completion_orb_anchor.position

	if highlight_mesh != null:
		highlight_mesh.position = Vector3(0.0, TILE_SURFACE_Y + 0.05, 0.0)
	if highlight_cross_mesh != null:
		highlight_cross_mesh.position = Vector3(0.0, TILE_SURFACE_Y + 0.05, 0.0)
	if color_code_label != null:
		color_code_label.position = Vector3(0.0, TILE_SURFACE_Y + 0.015, 0.0)
		color_code_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

func _apply_completion_orb_visuals() -> void:
	_ensure_node_refs()

	completion_orb_mesh.mesh = LEVEL_RENDER_RESOURCES.get_orb_shell_mesh()
	_orb_shell_material = StandardMaterial3D.new()
	_orb_shell_material.albedo_color = Color(source_color.r, source_color.g, source_color.b, 0.24)
	_orb_shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orb_shell_material.roughness = 0.06
	_orb_shell_material.metallic = 0.0
	_orb_shell_material.emission_enabled = true
	_orb_shell_material.emission = source_color
	_orb_shell_material.emission_energy_multiplier = _orb_base_emission_energy
	_orb_shell_material.refraction_enabled = true
	_orb_shell_material.refraction_scale = 0.04
	completion_orb_mesh.material_override = _orb_shell_material

	if completion_orb_core_mesh != null:
		completion_orb_core_mesh.mesh = LEVEL_RENDER_RESOURCES.get_orb_core_mesh()
		_orb_core_material = StandardMaterial3D.new()
		_orb_core_material.albedo_color = Color(source_color.r, source_color.g, source_color.b, 0.95)
		_orb_core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_orb_core_material.roughness = 0.18
		_orb_core_material.metallic = 0.0
		_orb_core_material.emission_enabled = true
		_orb_core_material.emission = source_color.lightened(0.08)
		_orb_core_material.emission_energy_multiplier = _orb_base_emission_energy * 0.75
		completion_orb_core_mesh.material_override = _orb_core_material

func _apply_highlight_visuals() -> void:
	_ensure_node_refs()
	if highlight_mesh == null:
		return

	highlight_mesh.mesh = LEVEL_RENDER_RESOURCES.get_highlight_forward_mesh()
	highlight_mesh.visible = false

	if highlight_cross_mesh != null:
		highlight_cross_mesh.mesh = LEVEL_RENDER_RESOURCES.get_highlight_cross_mesh()
		highlight_cross_mesh.visible = false

	_highlight_material = StandardMaterial3D.new()
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.emission_enabled = true
	_highlight_material.roughness = 0.05
	_highlight_material.metallic = 0.0
	highlight_mesh.material_override = _highlight_material
	if highlight_cross_mesh != null:
		highlight_cross_mesh.material_override = _highlight_material

	_update_highlight_visual()

func _apply_color_code_label() -> void:
	_ensure_node_refs()
	if color_code_label == null:
		return

	color_code_label.text = color_code
	color_code_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	color_code_label.modulate = Color(0.18, 0.13, 0.09, 1.0)
	color_code_label.outline_modulate = Color(0.90, 0.86, 0.72, 1.0)
	color_code_label.outline_size = 2
	color_code_label.font_size = 54
	color_code_label.visible = false

func _apply_tile_base_material() -> void:
	_ensure_node_refs()
	if tile_base == null:
		return

	if is_completed:
		tile_base.material_override = LEVEL_RENDER_RESOURCES.get_completed_tile_material(source_color)
	else:
		tile_base.material_override = LEVEL_RENDER_RESOURCES.get_incomplete_tile_material()

func _update_highlight_visual() -> void:
	_ensure_node_refs()
	if highlight_mesh == null:
		return

	if not is_highlighted or is_completed:
		highlight_mesh.visible = false
		if highlight_cross_mesh != null:
			highlight_cross_mesh.visible = false
		return

	highlight_mesh.visible = true
	if highlight_cross_mesh != null:
		highlight_cross_mesh.visible = true

	if _highlight_material == null:
		return

	var pulse: float = (sin(_highlight_time * 6.0) + 1.0) * 0.5
	_highlight_material.albedo_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.70 + (pulse * 0.22))
	_highlight_material.emission = highlight_color
	_highlight_material.emission_energy_multiplier = 4.4 + (pulse * 3.2)

func _update_color_code_visibility() -> void:
	_ensure_node_refs()
	if color_code_label == null:
		return
	color_code_label.visible = _code_label_forced_visible and (not is_completed)

func set_code_label_visible(label_visible: bool) -> void:
	_code_label_forced_visible = label_visible
	_update_color_code_visibility()

func set_highlight_color(new_color: Color) -> void:
	highlight_color = new_color
	_update_highlight_visual()


func set_runtime_tile_index(new_runtime_tile_index: int) -> void:
	runtime_tile_index = new_runtime_tile_index

func apply_runtime_state(new_is_completed: bool) -> void:
	if new_is_completed:
		set_completed()
	else:
		set_incomplete()

func set_incomplete() -> void:
	_ensure_node_refs()

	is_completed = false
	_orb_time = 0.0

	completion_orb_mesh.visible = false
	if completion_orb_core_mesh != null:
		completion_orb_core_mesh.visible = false
	completion_orb_anchor.position = _base_orb_anchor_position
	completion_orb_mesh.scale = Vector3.ONE
	if completion_orb_core_mesh != null:
		completion_orb_core_mesh.scale = Vector3.ONE

	_apply_tile_base_material()
	_update_highlight_visual()
	_update_color_code_visibility()

func set_completed() -> void:
	_ensure_node_refs()

	is_completed = true
	is_highlighted = false
	_orb_time = 0.0
	_code_label_forced_visible = false

	completion_orb_mesh.visible = true
	if completion_orb_core_mesh != null:
		completion_orb_core_mesh.visible = true
	completion_orb_anchor.position = _base_orb_anchor_position
	completion_orb_mesh.scale = Vector3.ONE
	if completion_orb_core_mesh != null:
		completion_orb_core_mesh.scale = Vector3.ONE

	_apply_tile_base_material()
	_update_highlight_visual()
	_update_color_code_visibility()

	if _orb_shell_material != null:
		_orb_shell_material.emission = source_color
		_orb_shell_material.emission_energy_multiplier = _orb_base_emission_energy
		_orb_shell_material.albedo_color = Color(source_color.r, source_color.g, source_color.b, 0.24)

	if _orb_core_material != null:
		_orb_core_material.emission = source_color.lightened(0.08)
		_orb_core_material.emission_energy_multiplier = _orb_base_emission_energy * 0.75
		_orb_core_material.albedo_color = Color(source_color.r, source_color.g, source_color.b, 0.95)

func get_tile_center_world() -> Vector3:
	_ensure_node_refs()
	if completion_orb_anchor == null:
		return global_position
	return completion_orb_anchor.global_position

func set_highlighted(is_on: bool) -> void:
	if is_completed:
		is_highlighted = false
	else:
		if is_on and not is_highlighted:
			_highlight_time = 0.0
		is_highlighted = is_on
	_update_highlight_visual()