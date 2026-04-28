extends Node3D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const LEVEL_GENERATOR_SCRIPT := preload("res://systems/level_runtime/LevelGenerator.gd")
const LEVEL_CONTENT_LIBRARY_SCRIPT := preload("res://systems/level_runtime/LevelContentLibrary.gd")
const LEVEL_SESSION_STATE_SCRIPT := preload("res://systems/level_runtime/LevelSessionState.gd")
const LEVEL_RUNTIME_BUILDER_SCRIPT := preload("res://systems/level_runtime/LevelRuntimeBuilder.gd")
const LEVEL_CHUNK_MANAGER_SCRIPT := preload("res://systems/level_runtime/LevelChunkManager.gd")
const LEVEL_SAVE_SYSTEM_SCRIPT := preload("res://systems/level_progress/LevelSaveSystem.gd")
const LEVEL_UNLOCK_SERVICE_SCRIPT := preload("res://systems/level_progress/LevelUnlockService.gd")
const COMPLETION_ORB_PROJECTILE_SCENE := preload("res://scenes/generated/CompletionOrbProjectile.tscn")
const LEVEL_MINIMAP_SCRIPT := preload("res://scripts/ui/LevelMinimap.gd")
const HOLDING_ROOM_PEDESTAL_LAYOUT_SCENE := preload("res://scenes/level_select/HoldingRoomPedestalLayout.tscn")
const TILE_TARGET_HIGHLIGHT_SCENE := preload("res://scenes/generated/TileTargetHighlight.tscn")
const NEARBY_TILE_CODE_LABEL_POOL_SCRIPT := preload("res://scripts/ui/NearbyTileCodeLabelPool.gd")
const LEVEL_INFO_PANEL_SCRIPT := preload("res://scripts/ui/LevelInfoPanel.gd")

const TILE_INTERACT_RANGE: float = 4.7
const TILE_INTERACT_MIN_DISTANCE: float = 2.9
const TILE_INTERACT_PREFERRED_DISTANCE: float = 3.8
const TILE_INTERACT_MIN_ALIGNMENT: float = 0.48
const TILE_LABEL_VISIBILITY_RADIUS: float = 30.0
const MAX_SAFE_VISIBLE_PIXELS: int = 12000
const PEDESTAL_INTERACT_RANGE: float = 6.0
const PEDESTAL_INTERACT_MIN_ALIGNMENT: float = 0.12
const AUTOSAVE_INTERVAL_SEC: float = 15.0
const PLAYER_ACCENT_COLORS: Array[Color] = [
	Color(0.10, 0.56, 1.00, 1.0),
	Color(1.00, 0.18, 0.18, 1.0),
	Color(0.10, 0.92, 0.28, 1.0),
	Color(1.00, 0.92, 0.10, 1.0),
	Color(1.00, 0.50, 0.10, 1.0),
	Color(0.72, 0.28, 1.00, 1.0),
]

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var world_root: Node3D = $WorldRoot
@onready var holding_room_root: Node3D = $WorldRoot/HoldingRoomRoot
@onready var active_level_root: Node3D = $WorldRoot/ActiveLevelRoot
@onready var players: Node3D = $Players
@onready var menu_root: Control = $CanvasLayer/MainMenuRoot
@onready var session_root: Control = $CanvasLayer/SessionRoot
@onready var session_status_label: Label = $CanvasLayer/SessionRoot/PanelContainer/MarginContainer/VBoxContainer/StatusLabel

var _current_level_node: Node3D = null
var _current_level_definition: Resource = null
var _current_theme: Resource = null
var _level_generator = LEVEL_GENERATOR_SCRIPT.new()
var _level_content_library = LEVEL_CONTENT_LIBRARY_SCRIPT.new()
var _level_session_state: Resource = LEVEL_SESSION_STATE_SCRIPT.new()
var _level_runtime_builder = LEVEL_RUNTIME_BUILDER_SCRIPT.new()
var _level_runtime_data: Resource = null
var _level_chunk_manager = LEVEL_CHUNK_MANAGER_SCRIPT.new()
var _level_save_system = LEVEL_SAVE_SYSTEM_SCRIPT.new()
var _level_unlock_service = LEVEL_UNLOCK_SERVICE_SCRIPT.new()
var _current_target_tile_index: int = -1
var _current_target_pedestal: Node = null
var _autosave_timer: Timer = null
var _last_session_active: bool = false
var _pedestal_root: Node3D = null
var _tile_target_highlight: Node3D = null
var _nearby_tile_code_label_pool = NEARBY_TILE_CODE_LABEL_POOL_SCRIPT.new()
var _controller_interact_was_pressed: bool = false
var _controller_prev_color_was_active: bool = false
var _controller_next_color_was_active: bool = false

var _selected_palette: Array = []
var _selected_palette_index: int = 0

var _selected_color_panel: PanelContainer = null
var _selected_color_swatch: ColorRect = null
var _selected_color_label: Label = null
var _progress_panel: PanelContainer = null
var _progress_label: Label = null
var _minimap_panel: PanelContainer = null
var _minimap_control: Control = null
var _level_info_panel: Control = null

func _ready() -> void:
	SessionState.player_registry_changed.connect(_sync_player_nodes)
	SessionState.player_zone_changed.connect(_on_player_zone_changed)
	SessionState.selected_level_changed.connect(_on_selected_level_changed)
	SessionState.session_state_changed.connect(_on_session_state_changed)
	SteamNet.status_changed.connect(_on_status_changed)

	_load_local_progress()
	_setup_hud()
	_setup_autosave_timer()

	_build_world()
	_on_session_state_changed()
	_last_session_active = SessionState.session_active
	call_deferred("_ensure_local_camera")

func _exit_tree() -> void:
	_flush_and_save_local_progress(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_and_save_local_progress(true)

func _physics_process(_delta: float) -> void:
	_update_active_chunks_for_local_player()
	_refresh_dirty_visible_chunks()
	_update_local_interaction_targets()
	_update_nearby_tile_labels()
	_process_controller_shortcuts()

	if Input.is_action_just_pressed("cycle_color_prev"):
		_cycle_selected_color(-1)
	if Input.is_action_just_pressed("cycle_color_next"):
		_cycle_selected_color(1)

	if Input.is_action_just_pressed("interact_tile"):
		_try_primary_interact()

func _process_controller_shortcuts() -> void:
	var device_id: int = _get_primary_joypad_device()
	if device_id == -1:
		_controller_interact_was_pressed = false
		_controller_prev_color_was_active = false
		_controller_next_color_was_active = false
		return

	var interact_pressed: bool = Input.is_joy_button_pressed(device_id, 0 as JoyButton)
	if interact_pressed and not _controller_interact_was_pressed:
		_try_primary_interact()
	_controller_interact_was_pressed = interact_pressed

	var prev_active: bool = Input.get_joy_axis(device_id, 4 as JoyAxis) > 0.55
	if prev_active and not _controller_prev_color_was_active:
		_cycle_selected_color(-1)
	_controller_prev_color_was_active = prev_active

	var next_active: bool = Input.get_joy_axis(device_id, 5 as JoyAxis) > 0.55
	if next_active and not _controller_next_color_was_active:
		_cycle_selected_color(1)
	_controller_next_color_was_active = next_active

func _get_primary_joypad_device() -> int:
	var joypads: PackedInt32Array = Input.get_connected_joypads()
	if joypads.is_empty():
		return -1
	return int(joypads[0])

func _setup_hud() -> void:
	_selected_color_panel = PanelContainer.new()
	_selected_color_panel.visible = false
	_selected_color_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_selected_color_panel.position = Vector2(16.0, 16.0)
	_selected_color_panel.size = Vector2(210.0, 58.0)
	canvas_layer.add_child(_selected_color_panel)

	var selected_hbox := HBoxContainer.new()
	selected_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_color_panel.add_child(selected_hbox)

	_selected_color_swatch = ColorRect.new()
	_selected_color_swatch.custom_minimum_size = Vector2(34.0, 34.0)
	selected_hbox.add_child(_selected_color_swatch)

	_selected_color_label = Label.new()
	_selected_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_hbox.add_child(_selected_color_label)

	_progress_panel = PanelContainer.new()
	_progress_panel.visible = false
	_progress_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_progress_panel.position = Vector2(-236.0, 16.0)
	_progress_panel.size = Vector2(220.0, 58.0)
	canvas_layer.add_child(_progress_panel)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_panel.add_child(_progress_label)

	_minimap_panel = PanelContainer.new()
	_minimap_panel.visible = false
	_minimap_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap_panel.position = Vector2(16.0, -236.0)
	_minimap_panel.size = Vector2(220.0, 220.0)
	canvas_layer.add_child(_minimap_panel)

	_minimap_control = LEVEL_MINIMAP_SCRIPT.new()
	_minimap_control.custom_minimum_size = Vector2(208.0, 208.0)
	_minimap_panel.add_child(_minimap_control)

	_level_info_panel = LEVEL_INFO_PANEL_SCRIPT.new()
	_level_info_panel.visible = false
	_level_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_level_info_panel.position = Vector2(-320.0, 84.0)
	_level_info_panel.size = Vector2(300.0, 300.0)
	canvas_layer.add_child(_level_info_panel)

func _setup_autosave_timer() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutoSaveTimer"
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	add_child(_autosave_timer)

func _on_autosave_timer_timeout() -> void:
	_flush_and_save_local_progress(false)

func _load_local_progress() -> void:
	var profile_id: String = _get_local_progress_profile_id()
	var progress: Resource = _level_save_system.load_local_progress(profile_id)
	if progress != null:
		SteamNet.status_changed.emit("Loaded local progress from %s." % _level_save_system.get_loaded_save_path())

func _get_local_progress_profile_id() -> String:
	if SteamNet.steam_available and SteamNet.local_steam_id != 0:
		return str(SteamNet.local_steam_id)
	return "default"

func _flush_and_save_local_progress(emit_status: bool) -> void:
	_merge_active_session_into_local_progress()
	var save_result: int = _level_save_system.save_if_dirty(_get_local_progress_profile_id())
	if save_result != OK:
		if emit_status:
			SteamNet.status_changed.emit("Failed to save local progress.")
	elif emit_status:
		SteamNet.status_changed.emit("Saved local progress.")

func _merge_active_session_into_local_progress() -> void:
	if _current_level_definition == null:
		return
	if _level_session_state == null:
		return

	var local_progress: Resource = _level_save_system.get_local_progress()
	if not _level_unlock_service.can_receive_progress_for_level(_current_level_definition, local_progress):
		return

	_level_save_system.merge_session_progress(_current_level_definition, _level_session_state)

func _announce_player_nodes_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if SessionState.session_active and SessionState.players.size() > 0:
		SteamNet.mark_player_nodes_ready()

func _build_world() -> void:
	for child in holding_room_root.get_children():
		child.queue_free()
	for child in active_level_root.get_children():
		child.queue_free()

	var holding_room: Node3D = _make_room("HoldingRoom", Color(0.18, 0.35, 0.8, 1.0), Vector3.ZERO)
	holding_room_root.add_child(holding_room)
	_add_portal(holding_room, "EntryPortal", "enter_selected_level", true, Vector3(0.0, 0.25, -5.5))
	_build_level_select_pedestals(holding_room)

func _build_level_select_pedestals(parent_node: Node3D) -> void:
	_pedestal_root = HOLDING_ROOM_PEDESTAL_LAYOUT_SCENE.instantiate() as Node3D
	if _pedestal_root == null:
		_pedestal_root = Node3D.new()
		_pedestal_root.name = "PedestalRoot"
	else:
		_pedestal_root.name = "PedestalRoot"
	parent_node.add_child(_pedestal_root)
	_bind_placed_pedestals()
	_refresh_pedestal_visuals()
	_update_level_info_panel()

func _bind_placed_pedestals() -> void:
	if _pedestal_root == null:
		return
	var local_progress: Resource = _level_save_system.get_local_progress()
	for child in _pedestal_root.get_children():
		if child.has_method("bind_from_level_content_library"):
			child.bind_from_level_content_library(_level_content_library, local_progress)

func _get_pedestal_lookup_key(pedestal: Node) -> String:
	if pedestal == null:
		return ""
	if pedestal.has_method("get_lookup_key"):
		return str(pedestal.get_lookup_key())
	if "level_id" in pedestal and not str(pedestal.level_id).is_empty():
		return str(pedestal.level_id)
	if "level_key" in pedestal:
		return str(pedestal.level_key)
	return ""

func _refresh_pedestal_visuals() -> void:
	if _pedestal_root == null:
		return
	var local_color: Color = _get_local_player_accent_color()
	var local_progress: Resource = _level_save_system.get_local_progress()

	for child in _pedestal_root.get_children():
		if not child.has_method("set_runtime_state"):
			continue
		var entry: Resource = _level_content_library.get_catalog_entry(str(child.level_key), local_progress)
		var is_selected: bool = str(child.level_key) == str(SessionState.selected_level_key)
		var is_targeted: bool = child == _current_target_pedestal
		var is_locked: bool = true
		var is_completed: bool = false
		var lock_reason: String = ""
		if entry != null:
			is_locked = not bool(entry.is_unlocked)
			is_completed = bool(entry.is_completed)
			lock_reason = str(entry.unlock_reason)
			if child.has_method("configure_from_catalog_entry"):
				child.configure_from_catalog_entry(entry)
		child.set_runtime_state(is_selected, is_targeted, local_color, is_locked, is_completed, lock_reason)

	_update_level_info_panel()

func _on_session_state_changed() -> void:
	if _last_session_active and not SessionState.session_active:
		_flush_and_save_local_progress(true)

	world_root.visible = SessionState.session_active
	players.visible = SessionState.session_active
	session_root.visible = SessionState.session_active
	menu_root.visible = not SessionState.session_active
	_sync_player_nodes()
	_last_session_active = SessionState.session_active
	call_deferred("_ensure_local_camera")
	_update_level_info_panel()

func _sync_player_nodes() -> void:
	var desired: Dictionary = {}

	for peer_id_variant in SessionState.players.keys():
		var peer_id: int = int(peer_id_variant)
		desired[peer_id] = true

		var node = players.get_node_or_null(str(peer_id))
		if node == null:
			var player = PLAYER_SCENE.instantiate()
			player.name = str(peer_id)
			player.peer_id = peer_id
			player.display_name = SessionState.get_player_name(peer_id)
			player.set_multiplayer_authority(peer_id)
			players.add_child(player)
		else:
			node.display_name = SessionState.get_player_name(peer_id)
			if node.has_method("refresh_name"):
				node.refresh_name()

		_apply_player_slot_visuals(peer_id)
		_move_player_to_zone(peer_id, SessionState.get_player_zone(peer_id))

	for child in players.get_children():
		var child_id: int = int(child.name)
		if not desired.has(child_id):
			child.queue_free()

	if SessionState.session_active and SessionState.players.size() > 0:
		call_deferred("_announce_player_nodes_ready")

	if SteamNet.is_host() and _level_session_state.active_level_id != "" and _current_level_node != null:
		call_deferred("_broadcast_session_seed_to_clients")

	_refresh_pedestal_visuals()
	call_deferred("_ensure_local_camera")
	_refresh_minimap()
	_update_level_info_panel()

func _apply_player_slot_visuals(peer_id: int) -> void:
	var player = players.get_node_or_null(str(peer_id))
	if player == null:
		return
	if player.has_method("set_accent_color"):
		player.set_accent_color(_get_player_color_for_peer(peer_id))

func _get_player_color_for_peer(peer_id: int) -> Color:
	var slot_index: int = _get_spawn_slot(peer_id)
	return PLAYER_ACCENT_COLORS[slot_index % PLAYER_ACCENT_COLORS.size()]

func _get_local_player_accent_color() -> Color:
	return _get_player_color_for_peer(SteamNet.get_local_peer_id())

func _update_level_info_panel() -> void:
	if _level_info_panel == null:
		return
	if not SessionState.session_active:
		if _level_info_panel.has_method("clear_display"):
			_level_info_panel.clear_display()
		return
	if SessionState.get_player_zone(SteamNet.get_local_peer_id()) != "holding_room":
		if _level_info_panel.has_method("clear_display"):
			_level_info_panel.clear_display()
		return

	var entry: Resource = null
	if _current_target_pedestal != null and is_instance_valid(_current_target_pedestal):
		entry = _level_content_library.get_catalog_entry(_get_pedestal_lookup_key(_current_target_pedestal), _level_save_system.get_local_progress())
	elif not SessionState.selected_level_key.is_empty():
		entry = _level_content_library.get_catalog_entry(SessionState.selected_level_key, _level_save_system.get_local_progress())

	if _level_info_panel.has_method("update_from_catalog_entry"):
		_level_info_panel.update_from_catalog_entry(
			entry,
			entry != null and str(entry.level_key) == str(SessionState.selected_level_key),
			entry != null and _current_target_pedestal != null and is_instance_valid(_current_target_pedestal) and _get_pedestal_lookup_key(_current_target_pedestal) == str(entry.level_id)
		)


func apply_remote_player_transform(peer_id: int, pos: Vector3, yaw: float) -> void:
	var player = players.get_node_or_null(str(peer_id))
	if player == null:
		return
	if player.has_method("apply_remote_transform"):
		player.apply_remote_transform(pos, yaw)

func _clear_level_state() -> void:
	_selected_palette.clear()
	_selected_palette_index = 0
	_level_runtime_data = null
	if _level_chunk_manager != null:
		_level_chunk_manager.clear()
	if _nearby_tile_code_label_pool != null:
		_nearby_tile_code_label_pool.clear()
	_hide_all_tile_labels()
	_clear_current_tile_target()
	_clear_current_pedestal_target()
	_update_selected_color_hud()
	_update_progress_hud()
	if _minimap_control != null and _minimap_control.has_method("clear_state"):
		_minimap_control.clear_state()
	if _minimap_panel != null:
		_minimap_panel.visible = false
	_update_level_info_panel()

func _spawn_level_if_needed() -> void:
	_clear_current_tile_target()

	for child in active_level_root.get_children():
		child.queue_free()
	_current_level_node = null
	_current_level_definition = null
	_current_theme = null
	_level_runtime_data = null
	if _level_chunk_manager != null:
		_level_chunk_manager.clear()

	if SessionState.selected_level_key.is_empty():
		_level_session_state.reset()
		_clear_level_state()
		_refresh_pedestal_visuals()
		return

	var selected_entry: Resource = _level_content_library.get_catalog_entry(SessionState.selected_level_key, _level_save_system.get_local_progress())
	if selected_entry != null and not bool(selected_entry.is_unlocked):
		SteamNet.status_changed.emit(str(selected_entry.unlock_reason))
		_clear_level_state()
		_refresh_pedestal_visuals()
		return

	_current_level_definition = _level_content_library.get_level_definition(SessionState.selected_level_key)
	_current_theme = _level_content_library.get_theme_for_level_key(SessionState.selected_level_key)

	if _current_level_definition == null or _current_theme == null:
		_clear_level_state()
		_refresh_pedestal_visuals()
		return

	if _current_level_definition.get_pixel_count() > MAX_SAFE_VISIBLE_PIXELS:
		SteamNet.status_changed.emit("Level too dense for current M15 runtime safety cap (%d visible tiles max)." % MAX_SAFE_VISIBLE_PIXELS)
		_clear_level_state()
		_refresh_pedestal_visuals()
		return

	_build_color_selection_registry()
	_seed_generated_level_session(_current_level_definition, _current_theme)
	_level_runtime_data = _level_runtime_builder.build_runtime_data(
		_current_level_definition,
		_current_theme,
		_level_session_state
	)
	_level_chunk_manager.initialize_from_runtime_data(_level_runtime_data)
	if _level_runtime_data == null:
		SteamNet.status_changed.emit("Failed building level runtime data.")
		_clear_level_state()
		_refresh_pedestal_visuals()
		return

	_current_level_node = _level_generator.generate_level(
		_current_level_definition,
		_current_theme,
		_level_session_state.get_completed_pixel_ids_copy(),
		5,
		_level_runtime_data
	)
	if _current_level_node == null:
		return

	_current_level_node.name = "GeneratedLevelRoom"
	_current_level_node.position = Vector3(60.0, 0.0, 0.0)
	active_level_root.add_child(_current_level_node)
	if _nearby_tile_code_label_pool != null:
		_nearby_tile_code_label_pool.configure(_current_level_node)
	_ensure_tile_target_highlight()
	_sync_visual_tiles_from_runtime_data()
	_update_active_chunks_for_local_player(true)
	_refresh_dirty_visible_chunks()

	var portal_local_pos: Vector3 = _get_generated_level_return_portal_position(_current_level_node)
	_add_portal(_current_level_node, "ReturnPortal", "return_to_holding_room", false, portal_local_pos)

	_update_selected_color_hud()
	_update_progress_hud()
	_refresh_minimap()
	_update_nearby_tile_labels()
	_refresh_pedestal_visuals()

	if SteamNet.is_host():
		_broadcast_session_seed_to_clients()

func _build_color_selection_registry() -> void:
	_selected_palette.clear()
	_selected_palette_index = 0

	if _current_level_definition == null:
		return

	for entry in _current_level_definition.get_color_palette_entries():
		_selected_palette.append(entry)

func _cycle_selected_color(direction: int) -> void:
	if _selected_palette.is_empty():
		return

	var new_index: int = _selected_palette_index + direction
	if new_index < 0:
		new_index = _selected_palette.size() - 1
	elif new_index >= _selected_palette.size():
		new_index = 0

	_selected_palette_index = new_index
	_update_selected_color_hud()

func _get_selected_palette_entry() -> Dictionary:
	if _selected_palette.is_empty():
		return {}
	return Dictionary(_selected_palette[_selected_palette_index])

func _make_color_payload_from_entry(entry: Dictionary) -> Dictionary:
	var color_value: Color = entry.get("source_color", Color.WHITE)
	return {
		"color_key": str(entry.get("color_key", "")),
		"color_code": str(entry.get("color_code", "")),
		"r": color_value.r,
		"g": color_value.g,
		"b": color_value.b,
		"a": color_value.a,
	}

func _payload_to_color(payload: Dictionary) -> Color:
	return Color(
		float(payload.get("r", 1.0)),
		float(payload.get("g", 1.0)),
		float(payload.get("b", 1.0)),
		float(payload.get("a", 1.0))
	)

func _update_selected_color_hud() -> void:
	if _selected_color_panel == null:
		return

	if _selected_palette.is_empty() or _current_level_definition == null:
		_selected_color_panel.visible = false
		return

	var entry: Dictionary = _get_selected_palette_entry()
	_selected_color_panel.visible = SessionState.session_active and _current_level_definition != null
	_selected_color_swatch.color = entry.get("source_color", Color.WHITE)
	_selected_color_label.text = "Selected %s\n%d / %d" % [
		str(entry.get("color_code", "")),
		_selected_palette_index + 1,
		_selected_palette.size()
	]

func _get_floor_percent_complete() -> int:
	if _current_level_definition == null:
		return 0
	var total_tiles: int = _current_level_definition.get_pixel_count()
	if total_tiles <= 0:
		return 0

	var completed_tiles: int = _level_session_state.get_completed_tile_count()
	if completed_tiles >= total_tiles:
		return 100

	return int(floor((float(completed_tiles) / float(total_tiles)) * 100.0))

func _update_progress_hud() -> void:
	if _progress_panel == null:
		return

	if _current_level_definition == null:
		_progress_panel.visible = false
		return

	var total_tiles: int = _current_level_definition.get_pixel_count()
	var completed_tiles: int = _level_session_state.get_completed_tile_count()
	var percent_complete: int = _get_floor_percent_complete()

	_progress_panel.visible = SessionState.session_active and _current_level_definition != null
	_progress_label.text = "%s\n%d%% Complete\n%d / %d" % [
		str(_current_level_definition.level_name),
		percent_complete,
		completed_tiles,
		total_tiles
	]

func _refresh_minimap() -> void:
	if _minimap_control == null:
		return

	if _current_level_definition == null or _current_level_node == null or not SessionState.session_active:
		_minimap_panel.visible = false
		if _minimap_control.has_method("clear_state"):
			_minimap_control.clear_state()
		return

	var local_player: Node3D = _get_local_player_node()
	_minimap_panel.visible = true
	if _minimap_control.has_method("set_state"):
		_minimap_control.set_state(
			_current_level_definition,
			_level_session_state,
			_current_level_node,
			local_player
		)

func _ensure_tile_target_highlight() -> void:
	if _current_level_node == null:
		return
	if _tile_target_highlight != null and is_instance_valid(_tile_target_highlight):
		return

	_tile_target_highlight = TILE_TARGET_HIGHLIGHT_SCENE.instantiate()
	_tile_target_highlight.name = "TileTargetHighlight"
	_current_level_node.add_child(_tile_target_highlight)
	if _tile_target_highlight.has_method("set_highlight_color"):
		_tile_target_highlight.set_highlight_color(_get_local_player_accent_color())
	if _tile_target_highlight.has_method("clear_target"):
		_tile_target_highlight.clear_target()

func _sync_runtime_data_from_session_state() -> void:
	if _level_runtime_data == null:
		return
	_level_runtime_data.sync_completed_from_session_state(_level_session_state)

func _sync_visual_tiles_from_runtime_data() -> void:
	if _current_level_node == null:
		return
	if _level_runtime_data == null:
		return
	if _level_chunk_manager == null:
		return

	_level_chunk_manager.mark_all_chunks_dirty()
	_refresh_dirty_visible_chunks()


func _seed_generated_level_session(level_definition: Resource, theme: Resource) -> void:
	var local_progress: Resource = _level_save_system.get_local_progress()
	var theme_id: String = ""
	if theme != null:
		theme_id = str(theme.theme_id)

	if SteamNet.is_host() or not multiplayer.has_multiplayer_peer():
		_level_session_state.seed_from_host_progress(level_definition, theme_id, local_progress)
	else:
		if _level_session_state.active_level_id != str(level_definition.level_id):
			_level_session_state.seed_from_host_progress(level_definition, theme_id, local_progress)

func _broadcast_session_seed_to_clients() -> void:
	if not SteamNet.is_host():
		return
	if not multiplayer.has_multiplayer_peer():
		return
	_client_receive_session_seed.rpc(_level_session_state.to_dictionary())

@rpc("authority", "reliable")
func _client_receive_session_seed(data: Dictionary) -> void:
	_level_session_state.configure_from_dictionary(data)
	_sync_runtime_data_from_session_state()
	_sync_visual_tiles_from_runtime_data()
	if _level_chunk_manager != null:
		_level_chunk_manager.mark_all_chunks_dirty()
	_update_active_chunks_for_local_player(true)
	_refresh_dirty_visible_chunks()
	_update_progress_hud()
	_refresh_minimap()

func _get_generated_level_return_portal_position(level_node: Node3D) -> Vector3:
	if level_node == null:
		return Vector3(0.0, 0.25, -5.5)

	var room_depth_cells: int = int(level_node.get_meta("room_depth_cells", 16))
	var border_tiles: int = int(level_node.get_meta("border_tiles", 5))
	var cell_world_size: float = float(level_node.get_meta("cell_world_size", 2.0))
	var inside_front_margin_cells: float = max(float(border_tiles) - 1.5, 2.0)
	var front_z: float = (-(float(room_depth_cells) * 0.5) + inside_front_margin_cells) * cell_world_size
	return Vector3(0.0, 0.25, front_z)

func _make_room(node_name: String, color: Color, world_pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = world_pos

	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = color
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = color.darkened(0.25)

	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(16.0, 0.5, 16.0)
	floor_mesh.mesh = floor_box
	floor_mesh.position = Vector3(0.0, -0.25, 0.0)
	floor_mesh.material_override = floor_material
	root.add_child(floor_mesh)

	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(16.0, 0.5, 16.0)
	floor_collision.shape = floor_shape
	floor_body.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)

	for i in range(4):
		var wall_mesh := MeshInstance3D.new()
		var wall_box := BoxMesh.new()
		var wall_body := StaticBody3D.new()
		var wall_collision := CollisionShape3D.new()
		var wall_shape := BoxShape3D.new()

		if i < 2:
			wall_box.size = Vector3(16.0, 5.0, 0.5)
			wall_shape.size = Vector3(16.0, 5.0, 0.5)
		else:
			wall_box.size = Vector3(0.5, 5.0, 16.0)
			wall_shape.size = Vector3(0.5, 5.0, 16.0)

		wall_mesh.mesh = wall_box
		wall_mesh.material_override = wall_material
		wall_collision.shape = wall_shape
		wall_body.add_child(wall_collision)

		match i:
			0:
				wall_mesh.position = Vector3(0.0, 2.5, -8.0)
				wall_body.position = Vector3(0.0, 2.5, -8.0)
			1:
				wall_mesh.position = Vector3(0.0, 2.5, 8.0)
				wall_body.position = Vector3(0.0, 2.5, 8.0)
			2:
				wall_mesh.position = Vector3(-8.0, 2.5, 0.0)
				wall_body.position = Vector3(-8.0, 2.5, 0.0)
			3:
				wall_mesh.position = Vector3(8.0, 2.5, 0.0)
				wall_body.position = Vector3(8.0, 2.5, 0.0)

		root.add_child(wall_mesh)
		root.add_child(wall_body)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	root.add_child(light)

	return root

func _add_portal(parent_node: Node3D, node_name: String, action: String, require_host_to_open: bool, local_pos: Vector3) -> void:
	var portal = preload("res://scenes/PortalArea.tscn").instantiate()
	portal.name = node_name
	portal.action = action
	portal.require_host_to_open = require_host_to_open
	portal.position = local_pos
	parent_node.add_child(portal)

func _get_spawn_slot(peer_id: int) -> int:
	var ids: Array[int] = []
	for peer_id_variant in SessionState.players.keys():
		ids.append(int(peer_id_variant))
	ids.sort()
	return maxi(ids.find(peer_id), 0)

func _move_player_to_zone(peer_id: int, zone: String) -> void:
	var player = players.get_node_or_null(str(peer_id))
	if player == null:
		return
	_move_player_node_to_zone(player, zone)

func _move_player_node_to_zone(player: Node, zone: String) -> void:
	var peer_id: int = int(player.name)
	var slot_index: int = _get_spawn_slot(peer_id)
	var slot_col: int = slot_index % 4
	var slot_row: int = int(float(slot_index) / 4.0)
	var offset := Vector3(float(slot_col) * 2.5 - 3.75, 3.25, float(slot_row) * 2.5)

	var target_position := Vector3(0.0, 0.0, 3.0) + offset
	if zone == "level":
		target_position = Vector3(60.0, 0.0, 3.0) + offset

	if player is Node3D:
		if player.is_inside_tree():
			player.global_position = target_position
		else:
			player.position = target_position

	if "velocity" in player:
		player.velocity = Vector3.ZERO
	if player.has_method("clear_network_targets"):
		player.clear_network_targets()

func _on_selected_level_changed() -> void:
	_spawn_level_if_needed()
	_refresh_pedestal_visuals()
	_update_level_info_panel()
	var holding_room = holding_room_root.get_node_or_null("HoldingRoom")
	if holding_room != null:
		var portal = holding_room.get_node_or_null("EntryPortal")
		if portal != null and portal.has_method("_refresh_visual_state"):
			portal._refresh_visual_state()

func _on_player_zone_changed(peer_id: int, zone: String) -> void:
	_move_player_to_zone(peer_id, zone)
	if peer_id == SteamNet.get_local_peer_id() and zone != "level":
		_clear_current_tile_target()
	call_deferred("_ensure_local_camera")
	_refresh_minimap()

func _ensure_local_camera() -> void:
	for child in players.get_children():
		if child.has_method("is_local_player") and child.is_local_player():
			var camera: Camera3D = child.get_node_or_null("SpringArm3D/Camera3D")
			if camera != null:
				camera.current = true
				return

	var fallback := get_node_or_null("FallbackCamera") as Camera3D
	if fallback == null:
		fallback = Camera3D.new()
		fallback.name = "FallbackCamera"
		add_child(fallback)
	fallback.look_at_from_position(Vector3(0.0, 12.0, 16.0), Vector3(0.0, 1.0, 0.0), Vector3.UP)
	fallback.current = true

func _update_local_interaction_targets() -> void:
	if _can_local_target_tiles():
		_update_local_tile_target()
		_clear_current_pedestal_target()
	elif _can_local_target_pedestals():
		_update_local_pedestal_target()
		_clear_current_tile_target()
	else:
		_clear_current_tile_target()
		_clear_current_pedestal_target()

func _can_local_target_tiles() -> bool:
	if not SessionState.session_active:
		return false
	if _current_level_node == null:
		return false
	if _current_level_definition == null:
		return false
	if _level_runtime_data == null:
		return false
	if SessionState.get_player_zone(SteamNet.get_local_peer_id()) != "level":
		return false
	if _level_session_state.active_level_id == "":
		return false
	return true

func _can_local_target_pedestals() -> bool:
	if not SessionState.session_active:
		return false
	if not SteamNet.is_host():
		return false
	if _pedestal_root == null:
		return false
	if SessionState.get_player_zone(SteamNet.get_local_peer_id()) != "holding_room":
		return false
	return true

func _update_active_chunks_for_local_player(force_refresh: bool = false) -> void:
	if _current_level_node == null:
		return
	if _level_runtime_data == null:
		return
	if _level_chunk_manager == null:
		return

	var local_player: Node3D = _get_local_player_node()
	if local_player == null:
		return

	if SessionState.get_player_zone(SteamNet.get_local_peer_id()) != "level":
		if force_refresh:
			for chunk_index in range(_level_chunk_manager.get_chunk_count()):
				_level_generator.set_chunk_visible(_current_level_node, chunk_index, false)
				var hidden_state = _level_chunk_manager.get_chunk_state(chunk_index)
				if hidden_state != null:
					hidden_state.is_visible = false
			_level_chunk_manager.set_active_chunks([])
		return

	var local_position: Vector3 = _current_level_node.to_local(local_player.global_position)
	var active_chunk_indices: Array[int] = _level_chunk_manager.compute_active_chunk_indices_from_local_position(local_position, 2)
	_level_chunk_manager.set_active_chunks(active_chunk_indices)

	for chunk_index in range(_level_chunk_manager.get_chunk_count()):
		var is_active: bool = _level_chunk_manager.is_chunk_active(chunk_index)
		_level_generator.set_chunk_visible(_current_level_node, chunk_index, is_active)
		var state = _level_chunk_manager.get_chunk_state(chunk_index)
		if state != null:
			state.is_visible = is_active

func _refresh_dirty_visible_chunks() -> void:
	if _current_level_node == null:
		return
	if _level_runtime_data == null:
		return
	if _level_chunk_manager == null:
		return

	for chunk_index in _level_chunk_manager.get_active_chunk_indices():
		var state = _level_chunk_manager.get_chunk_state(chunk_index)
		if state == null:
			continue
		if not state.is_dirty:
			continue
		_level_generator.refresh_chunk_runtime_state(_current_level_node, _level_runtime_data, chunk_index)
		state.is_dirty = false
		state.is_built = true

func _mark_chunk_dirty_by_tile_index(tile_index: int) -> void:
	if _level_chunk_manager == null:
		return
	_level_chunk_manager.mark_chunk_dirty_by_tile_index(tile_index)

func _get_local_player_node() -> Node3D:
	for child in players.get_children():
		if child.has_method("is_local_player") and child.is_local_player():
			return child
	return null

func _hide_all_tile_labels() -> void:
	if _nearby_tile_code_label_pool == null:
		return
	_nearby_tile_code_label_pool.clear_assignments()


func _update_nearby_tile_labels() -> void:
	if not _can_local_target_tiles():
		_hide_all_tile_labels()
		return
	if _level_runtime_data == null:
		_hide_all_tile_labels()
		return
	if _nearby_tile_code_label_pool == null:
		return

	var local_player: Node3D = _get_local_player_node()
	if local_player == null:
		_hide_all_tile_labels()
		return

	var active_chunk_indices: Array[int] = []
	if _level_chunk_manager != null:
		active_chunk_indices = _level_chunk_manager.get_active_chunk_indices()

	var player_forward: Vector3 = -local_player.global_transform.basis.z.normalized()

	_nearby_tile_code_label_pool.update_labels(
		_level_runtime_data,
		active_chunk_indices,
		_current_target_tile_index,
		local_player.global_position,
		player_forward,
		TILE_LABEL_VISIBILITY_RADIUS
	)

func _update_local_tile_target() -> void:
	var local_player: Node3D = _get_local_player_node()
	if local_player == null:
		_clear_current_tile_target()
		return

	var next_target_index: int = _find_best_interaction_tile_index(local_player)
	if next_target_index == _current_target_tile_index:
		return
	_set_current_tile_target(next_target_index)

func _update_local_pedestal_target() -> void:
	var local_player: Node3D = _get_local_player_node()
	if local_player == null:
		_clear_current_pedestal_target()
		return

	var next_target: Node = _find_best_interaction_pedestal(local_player)
	if next_target == _current_target_pedestal:
		return
	_set_current_pedestal_target(next_target)

func _find_best_interaction_tile_index(local_player: Node3D) -> int:
	if _current_level_node == null:
		return -1
	if _level_runtime_data == null:
		return -1

	var player_origin: Vector3 = local_player.global_position + Vector3(0.0, 0.95, 0.0)
	var player_forward: Vector3 = -local_player.global_transform.basis.z.normalized()

	var candidate_tile_indices: Array[int] = []
	if _level_chunk_manager != null:
		for chunk_index in _level_chunk_manager.get_active_chunk_indices():
			for tile_index in _level_runtime_data.get_chunk_tile_indices(chunk_index):
				candidate_tile_indices.append(int(tile_index))
	else:
		for tile_index in range(_level_runtime_data.tile_count):
			candidate_tile_indices.append(tile_index)

	var best_tile_index: int = -1
	var best_score: float = -999999.0

	for tile_index in candidate_tile_indices:
		if _level_runtime_data.is_tile_completed_by_index(tile_index):
			continue

		var target_world: Vector3 = _current_level_node.to_global(_level_runtime_data.get_tile_local_position(tile_index))
		var to_tile: Vector3 = target_world - player_origin
		var flat_to_tile: Vector3 = Vector3(to_tile.x, 0.0, to_tile.z)
		var dist: float = flat_to_tile.length()
		if dist <= 0.001:
			continue
		if dist < TILE_INTERACT_MIN_DISTANCE:
			continue
		if dist > TILE_INTERACT_RANGE:
			continue

		var direction_to_tile: Vector3 = flat_to_tile.normalized()
		var alignment: float = direction_to_tile.dot(player_forward)
		if alignment < TILE_INTERACT_MIN_ALIGNMENT:
			continue

		var side_amount: float = abs(direction_to_tile.cross(player_forward).y)
		var distance_bias: float = 1.0 - abs(dist - TILE_INTERACT_PREFERRED_DISTANCE)
		var score: float = (alignment * 5.2) + (distance_bias * 2.2) - (side_amount * 1.35)

		if best_tile_index == -1 or score > best_score:
			best_tile_index = tile_index
			best_score = score

	return best_tile_index

func _find_best_interaction_pedestal(local_player: Node3D) -> Node:
	if _pedestal_root == null:
		return null

	var player_origin: Vector3 = local_player.global_position + Vector3(0.0, 1.0, 0.0)
	var player_forward: Vector3 = -local_player.global_transform.basis.z.normalized()

	var best_target: Node = null
	var best_score: float = -999999.0

	for child in _pedestal_root.get_children():
		var to_target: Vector3 = child.global_position + Vector3(0.0, 1.0, 0.0) - player_origin
		var flat_to_target: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
		var dist: float = flat_to_target.length()
		if dist <= 0.001:
			continue
		if dist > PEDESTAL_INTERACT_RANGE:
			continue

		var direction_to_target: Vector3 = flat_to_target.normalized()
		var alignment: float = direction_to_target.dot(player_forward)
		if alignment < PEDESTAL_INTERACT_MIN_ALIGNMENT:
			continue

		var score: float = (alignment * 3.2) - (dist * 0.55)
		if best_target == null or score > best_score:
			best_target = child
			best_score = score

	return best_target

func _set_current_tile_target(tile_index: int) -> void:
	_current_target_tile_index = tile_index
	_ensure_tile_target_highlight()
	if _tile_target_highlight == null:
		return

	if _level_runtime_data == null or not _level_runtime_data.is_valid_tile_index(tile_index) or _current_level_node == null:
		if _tile_target_highlight.has_method("clear_target"):
			_tile_target_highlight.clear_target()
		return

	var local_position: Vector3 = _level_runtime_data.get_tile_local_position(tile_index)
	if _tile_target_highlight.has_method("set_highlight_color"):
		_tile_target_highlight.set_highlight_color(_get_local_player_accent_color())
	if _tile_target_highlight.has_method("set_target_local_position"):
		_tile_target_highlight.set_target_local_position(local_position)

func _clear_current_tile_target() -> void:
	_current_target_tile_index = -1
	if _tile_target_highlight != null and _tile_target_highlight.has_method("clear_target"):
		_tile_target_highlight.clear_target()

func _set_current_pedestal_target(target: Node) -> void:
	_current_target_pedestal = target
	_refresh_pedestal_visuals()
	_update_level_info_panel()

func _clear_current_pedestal_target() -> void:
	_current_target_pedestal = null
	_refresh_pedestal_visuals()
	_update_level_info_panel()

func _try_primary_interact() -> void:
	if _can_local_target_tiles():
		_try_interact_with_target_tile()
	elif _can_local_target_pedestals():
		_try_interact_with_target_pedestal()

func _try_interact_with_target_pedestal() -> void:
	if _current_target_pedestal == null:
		return
	if not is_instance_valid(_current_target_pedestal):
		_clear_current_pedestal_target()
		return
	if not SteamNet.is_host():
		return

	var pedestal_lookup_key: String = _get_pedestal_lookup_key(_current_target_pedestal)
	var entry: Resource = _level_content_library.get_catalog_entry(pedestal_lookup_key, _level_save_system.get_local_progress())
	if entry == null:
		SteamNet.status_changed.emit("That level could not be loaded.")
		return
	if not bool(entry.is_unlocked):
		var lock_reason: String = str(entry.unlock_reason)
		if lock_reason.is_empty():
			lock_reason = "That level is locked."
		SteamNet.status_changed.emit(lock_reason)
		return
	SteamNet.host_select_level(str(entry.level_key))

func _try_interact_with_target_tile() -> void:
	if _level_runtime_data == null:
		return
	if not _level_runtime_data.is_valid_tile_index(_current_target_tile_index):
		return
	if _current_level_definition == null:
		return
	if SessionState.get_player_zone(SteamNet.get_local_peer_id()) != "level":
		return

	var selected_entry: Dictionary = _get_selected_palette_entry()
	if selected_entry.is_empty():
		return

	var level_id: String = str(_level_session_state.active_level_id)
	var pixel_id: int = _level_runtime_data.get_tile_pixel_id(_current_target_tile_index)
	var payload: Dictionary = _make_color_payload_from_entry(selected_entry)

	if SteamNet.is_host() or not multiplayer.has_multiplayer_peer():
		_host_process_tile_attempt(level_id, pixel_id, SteamNet.get_local_peer_id(), payload)
	else:
		_request_tile_attempt.rpc_id(SteamNet.get_host_peer_id(), level_id, pixel_id, payload)

@rpc("any_peer", "reliable")
func _request_tile_attempt(level_id: String, pixel_id: int, payload: Dictionary) -> void:
	if not SteamNet.is_host():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_host_process_tile_attempt(level_id, pixel_id, sender, payload)

func _host_process_tile_attempt(level_id: String, pixel_id: int, acting_peer_id: int, payload: Dictionary) -> void:
	if not _can_host_attempt_tile(level_id, pixel_id):
		return
	if _level_runtime_data == null:
		return

	var tile_index: int = _level_runtime_data.get_tile_index_by_pixel_id(pixel_id)
	if tile_index == -1:
		return

	var was_match: bool = str(payload.get("color_key", "")) == _level_runtime_data.get_tile_color_key(tile_index)
	if was_match:
		_level_runtime_data.set_tile_completed_by_index(tile_index, true)
		_level_session_state.complete_tile(pixel_id)

	_apply_tile_attempt_local(level_id, pixel_id, acting_peer_id, payload, was_match)

	if multiplayer.has_multiplayer_peer():
		_client_receive_tile_attempt.rpc(level_id, pixel_id, acting_peer_id, payload, was_match)

@rpc("authority", "reliable")
func _client_receive_tile_attempt(
	level_id: String,
	pixel_id: int,
	acting_peer_id: int,
	payload: Dictionary,
	was_match: bool
) -> void:
	_apply_tile_attempt_local(level_id, pixel_id, acting_peer_id, payload, was_match)

func _can_host_attempt_tile(level_id: String, pixel_id: int) -> bool:
	if _current_level_definition == null:
		return false
	if _current_level_node == null:
		return false
	if _level_runtime_data == null:
		return false
	if level_id != str(_level_session_state.active_level_id):
		return false
	if not _current_level_definition.has_pixel_id(pixel_id):
		return false

	var tile_index: int = _level_runtime_data.get_tile_index_by_pixel_id(pixel_id)
	if tile_index == -1:
		return false
	if _level_runtime_data.is_tile_completed_by_index(tile_index):
		return false
	return true

func _apply_tile_attempt_local(level_id: String, pixel_id: int, acting_peer_id: int, payload: Dictionary, was_match: bool) -> void:
	if _current_level_definition == null:
		return
	if _current_level_node == null:
		return
	if _level_runtime_data == null:
		return
	if level_id != str(_level_session_state.active_level_id):
		return

	var tile_index: int = _level_runtime_data.get_tile_index_by_pixel_id(pixel_id)
	if tile_index == -1:
		return

	if was_match:
		_level_runtime_data.set_tile_completed_by_index(tile_index, true)
		_level_session_state.complete_tile(pixel_id)

	_spawn_attempt_projectile(acting_peer_id, tile_index, payload, was_match)

func _spawn_attempt_projectile(acting_peer_id: int, tile_index: int, payload: Dictionary, was_match: bool) -> void:
	var effects_root: Node3D = _level_generator.get_effects_root(_current_level_node)
	if effects_root == null:
		_finalize_tile_attempt(tile_index, was_match)
		return

	var actor_position: Vector3 = _get_completion_start_position(acting_peer_id)
	var target_position: Vector3 = _current_level_node.to_global(_level_runtime_data.get_tile_local_position(tile_index))
	var projectile = COMPLETION_ORB_PROJECTILE_SCENE.instantiate()
	projectile.configure(actor_position, target_position, _payload_to_color(payload), 0.28)
	projectile.arrived.connect(Callable(self, "_finalize_tile_attempt").bind(tile_index, was_match))
	effects_root.add_child(projectile)

func _get_completion_start_position(acting_peer_id: int) -> Vector3:
	var player = players.get_node_or_null(str(acting_peer_id))
	if player == null:
		return Vector3(60.0, 1.2, 3.0)
	return (player as Node3D).global_position + Vector3(0.0, 1.15, 0.0)

func _finalize_tile_attempt(tile_index: int, was_match: bool) -> void:
	if not was_match:
		return
	if _level_runtime_data == null:
		return
	if not _level_runtime_data.is_valid_tile_index(tile_index):
		return

	var pixel_id: int = _level_runtime_data.get_tile_pixel_id(tile_index)
	_mark_chunk_dirty_by_tile_index(tile_index)
	_refresh_dirty_visible_chunks()

	if _current_target_tile_index == tile_index:
		_clear_current_tile_target()

	_apply_local_progress_for_tile(pixel_id)
	_check_for_local_level_completion()
	_update_progress_hud()
	_refresh_minimap()
	_update_nearby_tile_labels()

func _apply_local_progress_for_tile(pixel_id: int) -> void:
	if _current_level_definition == null:
		return
	var local_progress: Resource = _level_save_system.get_local_progress()
	if not _level_unlock_service.can_receive_progress_for_level(_current_level_definition, local_progress):
		return
	_level_save_system.mark_tile_completed(str(_current_level_definition.level_id), pixel_id)

func _check_for_local_level_completion() -> void:
	if _current_level_definition == null:
		return

	var total_tiles: int = _current_level_definition.get_pixel_count()
	if total_tiles <= 0:
		return
	if _level_session_state.get_completed_tile_count() < total_tiles:
		return

	_level_session_state.set_level_complete(true)

	var local_progress: Resource = _level_save_system.get_local_progress()
	if _level_unlock_service.can_receive_progress_for_level(_current_level_definition, local_progress):
		_level_save_system.mark_level_complete(str(_current_level_definition.level_id))
		_level_save_system.mark_dirty()
		_flush_and_save_local_progress(true)

func _on_status_changed(text: String) -> void:
	session_status_label.text = text

func _on_forest_pressed() -> void:
	SteamNet.host_select_level("Forest")

func _on_lava_pressed() -> void:
	SteamNet.host_select_level("Lava")

func _on_leave_pressed() -> void:
	_flush_and_save_local_progress(true)
	SteamNet.leave_session()