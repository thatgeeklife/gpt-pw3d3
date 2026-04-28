extends Node3D

## Lightweight visual-only projectile used when a tile completion is confirmed.
## It travels from the acting player toward the target tile and then disappears.

signal arrived()

var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var travel_duration: float = 0.24
var orb_color: Color = Color.WHITE

var _elapsed: float = 0.0
var _started: bool = false

var shell_mesh: MeshInstance3D = null
var core_mesh: MeshInstance3D = null

func _ready() -> void:
	_resolve_nodes()
	_apply_visuals()
	global_position = start_position
	_started = true

func _process(delta: float) -> void:
	if not _started:
		return

	_elapsed += delta
	var t: float = 1.0
	if travel_duration > 0.001:
		t = clamp(_elapsed / travel_duration, 0.0, 1.0)

	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	global_position = start_position.lerp(target_position, eased)

	var shell_material = shell_mesh.material_override
	if shell_material is StandardMaterial3D:
		shell_material.emission_energy_multiplier = 1.2 + (0.6 * (1.0 - t))

	var core_material = core_mesh.material_override
	if core_material is StandardMaterial3D:
		core_material.emission_energy_multiplier = 1.0 + (0.45 * (1.0 - t))

	if t >= 1.0:
		arrived.emit()
		queue_free()

func configure(new_start: Vector3, new_target: Vector3, new_color: Color, duration: float = 0.24) -> void:
	start_position = new_start
	target_position = new_target
	orb_color = new_color
	travel_duration = max(duration, 0.05)

func _resolve_nodes() -> void:
	if shell_mesh == null:
		shell_mesh = get_node_or_null("ShellMesh") as MeshInstance3D
	if core_mesh == null:
		core_mesh = get_node_or_null("CoreMesh") as MeshInstance3D

func _apply_visuals() -> void:
	_resolve_nodes()

	var shell_sphere := SphereMesh.new()
	shell_sphere.radius = 0.30
	shell_sphere.height = 0.60
	shell_mesh.mesh = shell_sphere

	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(orb_color.r, orb_color.g, orb_color.b, 0.24)
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.roughness = 0.08
	shell_material.metallic = 0.0
	shell_material.emission_enabled = true
	shell_material.emission = orb_color
	shell_material.emission_energy_multiplier = 1.2
	shell_material.refraction_enabled = true
	shell_material.refraction_scale = 0.04
	shell_mesh.material_override = shell_material

	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.17
	core_sphere.height = 0.34
	core_mesh.mesh = core_sphere

	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(orb_color.r, orb_color.g, orb_color.b, 0.95)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.roughness = 0.18
	core_material.metallic = 0.0
	core_material.emission_enabled = true
	core_material.emission = orb_color.lightened(0.08)
	core_material.emission_energy_multiplier = 1.0
	core_mesh.material_override = core_material