extends Area3D

@export var action: String = "enter_selected_level"
@export var require_host_to_open: bool = true

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	SessionState.selected_level_changed.connect(_refresh_visual_state)
	_refresh_visual_state()

func _refresh_visual_state() -> void:
	var active = action == "return_to_holding_room" or not SessionState.selected_level_key.is_empty()
	visible = active
	set_deferred("monitoring", active)

	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 2.5

	if action == "return_to_holding_room":
		mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
		mat.emission = Color(1.0, 0.85, 0.2, 1.0)
		label.text = "RETURN"
	elif SessionState.selected_level_key.is_empty():
		mat.albedo_color = Color(0.25, 0.25, 0.25, 1.0)
		mat.emission = Color(0.25, 0.25, 0.25, 1.0)
		label.text = "SELECT A LEVEL"
	elif require_host_to_open and not SessionState.level_open:
		mat.albedo_color = Color(0.2, 0.5, 1.0, 1.0)
		mat.emission = Color(0.2, 0.5, 1.0, 1.0)
		label.text = "HOST ENTERS %s" % str(SessionState.selected_level_key).to_upper()
	else:
		mat.albedo_color = Color(0.2, 0.9, 1.0, 1.0)
		mat.emission = Color(0.2, 0.9, 1.0, 1.0)
		label.text = "ENTER %s" % str(SessionState.selected_level_key).to_upper()

	mesh.material_override = mat

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("players"):
		return
	if not body.has_method("is_local_player") or not body.is_local_player():
		return

	var peer_id: int = int(body.get_peer_id())
	match action:
		"enter_selected_level":
			if SessionState.selected_level_key.is_empty():
				return
			if require_host_to_open and not SessionState.level_open and peer_id != SteamNet.get_host_peer_id():
				SteamNet.status_changed.emit("The host still needs to enter the portal first.")
				return
			SteamNet.request_enter_selected_level(peer_id)
		"return_to_holding_room":
			SteamNet.request_return_to_holding_room(peer_id)