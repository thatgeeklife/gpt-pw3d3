extends Node3D

const LEVEL_RENDER_RESOURCES := preload("res://systems/level_runtime/LevelRenderResources.gd")

var highlight_color: Color = Color(1.0, 0.85, 0.20, 1.0)
var _highlight_time: float = 0.0
var _highlight_material: StandardMaterial3D = null

@onready var forward_mesh: MeshInstance3D = $ForwardMesh
@onready var cross_mesh: MeshInstance3D = $CrossMesh

func _ready() -> void:
	forward_mesh.mesh = LEVEL_RENDER_RESOURCES.get_highlight_forward_mesh()
	cross_mesh.mesh = LEVEL_RENDER_RESOURCES.get_highlight_cross_mesh()

	_highlight_material = StandardMaterial3D.new()
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.emission_enabled = true
	_highlight_material.roughness = 0.05
	_highlight_material.metallic = 0.0
	forward_mesh.material_override = _highlight_material
	cross_mesh.material_override = _highlight_material

	visible = false

func _process(delta: float) -> void:
	if not visible:
		return

	_highlight_time += delta
	var pulse: float = (sin(_highlight_time * 6.0) + 1.0) * 0.5
	_highlight_material.albedo_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.70 + (pulse * 0.22))
	_highlight_material.emission = highlight_color
	_highlight_material.emission_energy_multiplier = 4.4 + (pulse * 3.2)

func set_highlight_color(new_color: Color) -> void:
	highlight_color = new_color

func set_target_local_position(local_position: Vector3) -> void:
	position = local_position + Vector3(0.0, 0.05, 0.0)
	visible = true
	_highlight_time = 0.0

func clear_target() -> void:
	visible = false