extends CharacterBody3D

@export var move_speed: float = 8.4
@export var jump_velocity: float = 5.0
@export var gravity_force: float = 18.0
@export var mouse_turn_sensitivity_deg: float = 0.22
@export var mouse_pitch_sensitivity_deg: float = 0.18
@export var controller_turn_speed_deg: float = 180.0
@export var controller_pitch_speed_deg: float = 140.0
@export var controller_left_deadzone: float = 0.20
@export var controller_right_deadzone: float = 0.18
@export var min_camera_pitch_deg: float = -65.0
@export var max_camera_pitch_deg: float = -14.0
@export var min_zoom_length: float = 3.0
@export var max_zoom_length: float = 8.5
@export var zoom_step: float = 0.55

const JOY_AXIS_LEFT_X_INDEX: JoyAxis = 0 as JoyAxis
const JOY_AXIS_LEFT_Y_INDEX: JoyAxis = 1 as JoyAxis
const JOY_AXIS_RIGHT_X_INDEX: JoyAxis = 2 as JoyAxis
const JOY_AXIS_RIGHT_Y_INDEX: JoyAxis = 3 as JoyAxis
const KEY_LEFT_ARROW: Key = 4194319 as Key
const KEY_UP_ARROW: Key = 4194320 as Key
const KEY_RIGHT_ARROW: Key = 4194321 as Key
const KEY_DOWN_ARROW: Key = 4194322 as Key

var peer_id: int = 1
var display_name: String = "Player"
var _camera_pitch_deg: float = -28.0
var _mouse_look_active: bool = false
var _accent_color: Color = Color(0.20, 0.60, 1.0, 1.0)
var _ring_decal: Decal = null

@onready var name_label: Label3D = $NameLabel
@onready var facing_cone: MeshInstance3D = $FacingCone
@onready var floor_ring: MeshInstance3D = $FloorRing
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _ready() -> void:
	add_to_group("players")
	set_multiplayer_authority(peer_id)
	refresh_name()

	spring_arm.collision_mask = 0
	spring_arm.margin = 0.05
	spring_arm.spring_length = clamp(spring_arm.spring_length, min_zoom_length, max_zoom_length)

	_camera_pitch_deg = spring_arm.rotation_degrees.x
	_apply_camera_follow_rotation()
	_ensure_ring_projection()

	var config := SceneReplicationConfig.new()
	var pos_path := NodePath(":position")
	var rot_path := NodePath(":rotation")

	config.add_property(pos_path)
	config.property_set_spawn(pos_path, true)
	config.property_set_sync(pos_path, true)
	config.property_set_replication_mode(pos_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	config.add_property(rot_path)
	config.property_set_spawn(rot_path, true)
	config.property_set_sync(rot_path, true)
	config.property_set_replication_mode(rot_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	synchronizer.root_path = NodePath("..")
	synchronizer.replication_config = config
	synchronizer.public_visibility = false

	camera.current = is_local_player()
	_apply_accent_color()

	if not SteamNet.sync_gate_changed.is_connected(_update_sync_gate):
		SteamNet.sync_gate_changed.connect(_update_sync_gate)

	call_deferred("_arm_sync")

func _exit_tree() -> void:
	if is_local_player() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if not is_local_player():
		return

	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event

		if mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_button_event.pressed:
				_mouse_look_active = true
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				_mouse_look_active = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return

		if mouse_button_event.pressed:
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_step, min_zoom_length, max_zoom_length)
			elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_step, min_zoom_length, max_zoom_length)

	elif event is InputEventMouseMotion:
		if _mouse_look_active and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var motion_event: InputEventMouseMotion = event
			rotation.y -= deg_to_rad(motion_event.relative.x * mouse_turn_sensitivity_deg)
			_camera_pitch_deg = clamp(
				_camera_pitch_deg - (motion_event.relative.y * mouse_pitch_sensitivity_deg),
				min_camera_pitch_deg,
				max_camera_pitch_deg
			)
			_apply_camera_follow_rotation()

	if event.is_action_pressed("ui_cancel"):
		_mouse_look_active = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _apply_camera_follow_rotation() -> void:
	spring_arm.rotation_degrees = Vector3(_camera_pitch_deg, 0.0, 0.0)

func _ensure_ring_projection() -> void:
	if _ring_decal == null:
		_ring_decal = Decal.new()
		_ring_decal.name = "FloorRingDecal"
		_ring_decal.position = Vector3(0.0, 1.2, 0.0)
		_ring_decal.size = Vector3(1.7, 2.4, 1.7)
		add_child(_ring_decal)

	if floor_ring != null:
		floor_ring.visible = true
		floor_ring.scale = Vector3(0.55, 0.55, 0.55)

func _arm_sync() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_update_sync_gate()

func _update_sync_gate() -> void:
	if not is_inside_tree():
		return
	synchronizer.public_visibility = is_multiplayer_authority() and SteamNet.can_publish_sync_for_peer(peer_id)

func refresh_name() -> void:
	name_label.text = display_name

func is_local_player() -> bool:
	return peer_id == SteamNet.get_local_peer_id()

func get_peer_id() -> int:
	return peer_id

func set_accent_color(new_color: Color) -> void:
	_accent_color = new_color
	_apply_accent_color()

func get_accent_color() -> Color:
	return _accent_color

func _apply_accent_color() -> void:
	if facing_cone != null:
		var cone_material := StandardMaterial3D.new()
		cone_material.albedo_color = _accent_color
		cone_material.emission_enabled = true
		cone_material.emission = _accent_color
		cone_material.emission_energy_multiplier = 0.75
		cone_material.roughness = 0.72
		facing_cone.material_override = cone_material

	_ensure_ring_projection()

	if floor_ring != null:
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_texture = load("res://assets/fx/player_ring.png")
		ring_material.albedo_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.92)
		ring_material.emission_enabled = true
		ring_material.emission = _accent_color
		ring_material.emission_energy_multiplier = 3.6
		ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		floor_ring.material_override = ring_material

	if _ring_decal != null:
		_ring_decal.texture_albedo = load("res://assets/fx/player_ring.png")
		_ring_decal.modulate = Color(_accent_color.r, _accent_color.g, _accent_color.b, 1.0)

func _physics_process(delta: float) -> void:
	if not SessionState.session_active:
		return
	if not is_multiplayer_authority():
		return

	_apply_controller_rotation(delta)

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var controller_move: Vector2 = _get_controller_move_vector()
	if controller_move.length() > input_dir.length():
		input_dir = controller_move

	var local_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	var world_dir: Vector3 = Basis(Vector3.UP, rotation.y) * local_dir

	velocity.x = world_dir.x * move_speed
	velocity.z = world_dir.z * move_speed

	if not is_on_floor():
		velocity.y -= gravity_force * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0

	move_and_slide()

func _apply_controller_rotation(delta: float) -> void:
	var device_id: int = _get_primary_joypad_device()
	if device_id == -1:
		return

	var right_x: float = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X_INDEX)
	var right_y: float = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y_INDEX)

	if abs(right_x) < controller_right_deadzone:
		right_x = 0.0
	if abs(right_y) < controller_right_deadzone:
		right_y = 0.0

	if right_x != 0.0:
		rotation.y -= deg_to_rad(right_x * controller_turn_speed_deg * delta)

	if right_y != 0.0:
		_camera_pitch_deg = clamp(
			_camera_pitch_deg + (right_y * controller_pitch_speed_deg * delta),
			min_camera_pitch_deg,
			max_camera_pitch_deg
		)
		_apply_camera_follow_rotation()
	elif right_x != 0.0:
		_apply_camera_follow_rotation()

func _get_keyboard_move_vector() -> Vector2:
	var x_axis: float = 0.0
	var y_axis: float = 0.0

	if Input.is_key_pressed(KEY_LEFT_ARROW):
		x_axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT_ARROW):
		x_axis += 1.0
	if Input.is_key_pressed(KEY_UP_ARROW):
		y_axis -= 1.0
	if Input.is_key_pressed(KEY_DOWN_ARROW):
		y_axis += 1.0

	if Input.is_key_pressed(KEY_A):
		x_axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		x_axis += 1.0
	if Input.is_key_pressed(KEY_W):
		y_axis -= 1.0
	if Input.is_key_pressed(KEY_S):
		y_axis += 1.0

	var value := Vector2(x_axis, y_axis)
	if value.length() > 1.0:
		value = value.normalized()
	return value

func _get_controller_move_vector() -> Vector2:
	var device_id: int = _get_primary_joypad_device()
	if device_id == -1:
		return Vector2.ZERO

	var left_x: float = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X_INDEX)
	var left_y: float = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y_INDEX)

	if abs(left_x) < controller_left_deadzone:
		left_x = 0.0
	if abs(left_y) < controller_left_deadzone:
		left_y = 0.0

	return Vector2(left_x, left_y)

func _get_primary_joypad_device() -> int:
	var joypads: PackedInt32Array = Input.get_connected_joypads()
	if joypads.is_empty():
		return -1
	return int(joypads[0])

func apply_remote_transform(_pos: Vector3, _yaw: float) -> void:
	pass

func clear_network_targets() -> void:
	pass