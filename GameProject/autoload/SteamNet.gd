extends Node

signal status_changed(text: String)
signal session_started(is_host: bool)
signal session_ended()
signal sync_gate_changed()
signal steam_ready(local_steam_id: int, persona_name: String)
signal lobby_list_updated(lobbies: Array)

const APP_ID := 480
const GAME_VERSION := "portal-coop-v50"
const LOBBY_NAME_KEY := "name"
const LOBBY_OWNER_KEY := "owner_steam_id"
const LOBBY_VERSION_KEY := "version"
const LOBBY_SELECTED_LEVEL_KEY := "selected_level"
const LOBBY_LEVEL_OPEN_KEY := "level_open"
const MAX_PLAYERS := 8
const DEMO_HOST := "127.0.0.1"
const DEMO_PORT := 1909

var peer: MultiplayerPeer = null
var is_current_host: bool = false
var steam_available = false
var using_demo_mode = true
var local_steam_id = 0
var local_persona_name = "Player"
var lobby_id = 0
var host_steam_id = 0
var available_lobbies: Array = []
var pending_lobby_join = false
var lobby_data_requested_ids: Dictionary = {}

## peer_id -> bool
var player_nodes_ready_peers: Dictionary = {}

func _ready() -> void:
	_connect_signals()
	_init_steam_if_available()
	if using_demo_mode:
		status_changed.emit("Ready. Steam not active in this run, demo host/join available.")

func _process(_delta: float) -> void:
	if steam_available:
		Steam.run_callbacks()

func _connect_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _init_steam_if_available() -> void:
	if not Engine.has_singleton("Steam"):
		return

	steam_available = true
	var init_result = Steam.steamInitEx(APP_ID, true)
	var ok = false

	if typeof(init_result) == TYPE_DICTIONARY:
		ok = int(init_result.get("status", 1)) == 0
	elif typeof(init_result) == TYPE_BOOL:
		ok = bool(init_result)

	if not ok:
		status_changed.emit("Steam found but failed to initialize: %s" % str(init_result))
		return

	using_demo_mode = false
	local_steam_id = int(Steam.getSteamID())
	local_persona_name = str(Steam.getPersonaName())
	_connect_steam_signals()
	steam_ready.emit(local_steam_id, local_persona_name)
	status_changed.emit("Steam ready for %s." % local_persona_name)

func _connect_steam_signals() -> void:
	_connect_signal_if_present(Steam, "lobby_created", Callable(self, "_on_lobby_created"))
	_connect_signal_if_present(Steam, "lobby_joined", Callable(self, "_on_lobby_joined"))
	_connect_signal_if_present(Steam, "lobby_match_list", Callable(self, "_on_lobby_match_list"))
	_connect_signal_if_present(Steam, "join_requested", Callable(self, "_on_join_requested"))
	_connect_signal_if_present(Steam, "game_lobby_join_requested", Callable(self, "_on_game_lobby_join_requested"))
	_connect_signal_if_present(Steam, "lobby_chat_update", Callable(self, "_on_lobby_chat_update"))
	_connect_signal_if_present(Steam, "lobby_data_update", Callable(self, "_on_lobby_data_update"))

func _connect_signal_if_present(emitter: Object, signal_name: String, callable: Callable) -> void:
	if emitter == null:
		return
	for info in emitter.get_signal_list():
		if str(info.name) == signal_name:
			if not emitter.is_connected(signal_name, callable):
				emitter.connect(signal_name, callable)
			return

func _extract_lobby_ids_from_match_result(match_result = null) -> Array:
	var lobby_ids: Array = []

	if typeof(match_result) == TYPE_ARRAY:
		for item in match_result:
			if typeof(item) == TYPE_DICTIONARY:
				var dict_lobby_id: int = int(item.get("lobby_id", item.get("id", 0)))
				if dict_lobby_id != 0:
					lobby_ids.append(dict_lobby_id)
			elif typeof(item) == TYPE_INT:
				var array_lobby_id: int = int(item)
				if array_lobby_id != 0:
					lobby_ids.append(array_lobby_id)

	elif typeof(match_result) == TYPE_INT:
		var result_count: int = int(match_result)
		if Steam.has_method("getLobbyByIndex"):
			for idx in range(result_count):
				var indexed_lobby = Steam.call("getLobbyByIndex", idx)
				var indexed_lobby_id: int = int(indexed_lobby)
				if indexed_lobby_id != 0:
					lobby_ids.append(indexed_lobby_id)

	if lobby_ids.is_empty() and Steam.has_method("getLobbyByIndex"):
		for idx in range(50):
			var fallback_lobby = Steam.call("getLobbyByIndex", idx)
			var fallback_lobby_id: int = int(fallback_lobby)
			if fallback_lobby_id == 0:
				break
			lobby_ids.append(fallback_lobby_id)

	return lobby_ids

func _extract_lobby_id_from_friend_game_info(info) -> int:
	if typeof(info) == TYPE_DICTIONARY:
		for key in info.keys():
			var key_text = str(key).to_lower()
			var value = info[key]
			if "lobby" in key_text:
				var lobby_candidate: int = int(value)
				if lobby_candidate != 0:
					return lobby_candidate
			if typeof(value) == TYPE_DICTIONARY:
				var nested_lobby: int = _extract_lobby_id_from_friend_game_info(value)
				if nested_lobby != 0:
					return nested_lobby
	return 0

func _friend_lobby_id_set() -> Dictionary:
	var lobby_ids: Dictionary = {}

	if not steam_available:
		return lobby_ids
	if not Steam.has_method("getFriendCount"):
		return lobby_ids
	if not Steam.has_method("getFriendByIndex"):
		return lobby_ids
	if not Steam.has_method("getFriendGamePlayed"):
		return lobby_ids

	var friend_flag_immediate = 4
	var friend_count: int = int(Steam.call("getFriendCount", friend_flag_immediate))
	for idx in range(friend_count):
		var friend_id: int = int(Steam.call("getFriendByIndex", idx, friend_flag_immediate))
		if friend_id == 0:
			continue

		var game_info = Steam.call("getFriendGamePlayed", friend_id)
		var lobby_id_from_friend: int = _extract_lobby_id_from_friend_game_info(game_info)
		if lobby_id_from_friend != 0:
			lobby_ids[lobby_id_from_friend] = true

	return lobby_ids

func _request_lobby_metadata_once(lobby_ids: Array) -> void:
	if not steam_available:
		return
	if not Steam.has_method("requestLobbyData"):
		return

	for lobby_variant in lobby_ids:
		var this_lobby_id: int = int(lobby_variant)
		if this_lobby_id == 0:
			continue
		if bool(lobby_data_requested_ids.get(this_lobby_id, false)):
			continue
		lobby_data_requested_ids[this_lobby_id] = true
		Steam.call("requestLobbyData", this_lobby_id)

func _rebuild_available_lobbies_from_ids(lobby_ids: Array) -> void:
	available_lobbies.clear()

	var friend_lobby_ids: Dictionary = _friend_lobby_id_set()

	for lobby_variant in lobby_ids:
		var this_lobby_id: int = int(lobby_variant)
		if this_lobby_id == 0:
			continue

		var display_name = ""
		var version = ""
		var owner_id = 0
		var member_count = 0

		if Steam.has_method("getLobbyData"):
			display_name = str(Steam.call("getLobbyData", this_lobby_id, LOBBY_NAME_KEY))
			version = str(Steam.call("getLobbyData", this_lobby_id, LOBBY_VERSION_KEY))
			owner_id = int(Steam.call("getLobbyData", this_lobby_id, LOBBY_OWNER_KEY))

		if not version.is_empty() and version != GAME_VERSION:
			continue

		# Only show lobbies that currently contain Steam friends, while still allowing
		# the local user's own active lobby to remain visible.
		var is_own_lobby = (this_lobby_id == lobby_id) or (owner_id != 0 and owner_id == local_steam_id)
		if not is_own_lobby and not friend_lobby_ids.is_empty() and not bool(friend_lobby_ids.get(this_lobby_id, false)):
			continue

		if display_name.is_empty():
			display_name = "Lobby %s" % str(this_lobby_id)

		if Steam.has_method("getNumLobbyMembers"):
			member_count = int(Steam.call("getNumLobbyMembers", this_lobby_id))

		available_lobbies.append({
			"lobby_id": this_lobby_id,
			"name": display_name,
			"owner_steam_id": owner_id,
			"members": member_count,
			"version": version,
		})

	lobby_list_updated.emit(available_lobbies)

func _current_visible_lobby_ids() -> Array:
	var ids: Array = []
	for lobby in available_lobbies:
		if typeof(lobby) == TYPE_DICTIONARY:
			var this_lobby_id: int = int(lobby.get("lobby_id", 0))
			if this_lobby_id != 0:
				ids.append(this_lobby_id)

	if ids.is_empty() and lobby_id != 0:
		ids.append(lobby_id)

	return ids

func request_lobby_list() -> void:
	if not steam_available:
		status_changed.emit("Steam is not active in this run.")
		return

	available_lobbies.clear()
	lobby_data_requested_ids.clear()
	lobby_list_updated.emit(available_lobbies)

	if Steam.has_method("addRequestLobbyListDistanceFilter"):
		if "LOBBY_DISTANCE_FILTER_WORLDWIDE" in Steam:
			Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
		else:
			Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_FAR)

	if Steam.has_method("addRequestLobbyListResultCountFilter"):
		Steam.addRequestLobbyListResultCountFilter(50)

	if Steam.has_method("requestLobbyList"):
		Steam.requestLobbyList()
		status_changed.emit("Refreshing Steam lobby list...")
	else:
		_rebuild_available_lobbies_from_ids(_current_visible_lobby_ids())
		status_changed.emit("Steam build has no requestLobbyList(); reused current visible lobby data.")

func join_lobby_by_id(target_lobby_id: int) -> void:
	if not steam_available:
		status_changed.emit("Steam is not active in this run.")
		return
	if target_lobby_id == 0:
		status_changed.emit("Invalid lobby ID.")
		return
	status_changed.emit("Joining Steam lobby %s..." % str(target_lobby_id))
	Steam.joinLobby(target_lobby_id)

func start_steam_host_session() -> void:
	if steam_available and _steam_peer_supported():
		_reset_session()
		is_current_host = true
		status_changed.emit("Creating Steam public lobby...")
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PLAYERS)
		return

	start_demo_host_session()
	status_changed.emit("Steam host fell back to demo transport because Steam or SteamMultiplayerPeer is not active.")

func start_demo_host_session() -> void:
	_reset_session()
	is_current_host = true

	var enet = ENetMultiplayerPeer.new()
	var err = enet.create_server(DEMO_PORT, MAX_PLAYERS)
	if err != OK:
		status_changed.emit("Host failed: %s" % error_string(err))
		return

	peer = enet
	multiplayer.multiplayer_peer = peer
	SessionState.set_session_active(true)
	SessionState.ensure_player(1, "Host")
	SessionState.set_player_zone(1, "holding_room")
	_reset_sync_gate_for_current_roster()
	session_started.emit(true)
	status_changed.emit("Demo host started on 127.0.0.1:%d." % DEMO_PORT)

func start_demo_joined_session() -> void:
	_reset_session()
	is_current_host = false

	var enet = ENetMultiplayerPeer.new()
	var err = enet.create_client(DEMO_HOST, DEMO_PORT)
	if err != OK:
		status_changed.emit("Join failed: %s" % error_string(err))
		return

	peer = enet
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Joining host...")

func invite_friends() -> void:
	if steam_available and lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)
	else:
		status_changed.emit("Create or join a Steam lobby first.")

func leave_session() -> void:
	if multiplayer.has_multiplayer_peer():
		if is_host():
			_notify_session_closed.rpc("Host closed the session.")
		_shutdown_peer()

	if steam_available and lobby_id != 0:
		Steam.leaveLobby(lobby_id)

	lobby_id = 0
	host_steam_id = 0
	pending_lobby_join = false
	available_lobbies.clear()
	lobby_data_requested_ids.clear()
	lobby_list_updated.emit(available_lobbies)
	SessionState.reset()
	is_current_host = false
	player_nodes_ready_peers.clear()
	session_ended.emit()
	sync_gate_changed.emit()
	status_changed.emit("Left session.")

func is_host() -> bool:
	return (multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or (not multiplayer.has_multiplayer_peer() and is_current_host)

func get_local_peer_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1 if is_current_host else 2

func get_local_display_name() -> String:
	return local_persona_name if steam_available else ("Host" if is_current_host else "Client")

func get_host_peer_id() -> int:
	if is_host() and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	for peer_id_variant in SessionState.players.keys():
		var peer_id: int = int(peer_id_variant)
		var info: Dictionary = SessionState.players[peer_id]
		if int(info.get("steam_id", 0)) == host_steam_id:
			return peer_id
	return 1

func can_publish_sync_for_peer(_peer_id: int) -> bool:
	for peer_id_variant in SessionState.players.keys():
		var peer_id: int = int(peer_id_variant)
		if not bool(player_nodes_ready_peers.get(peer_id, false)):
			return false
	return SessionState.players.size() > 0

func mark_player_nodes_ready() -> void:
	var local_peer_id = get_local_peer_id()
	player_nodes_ready_peers[local_peer_id] = true
	sync_gate_changed.emit()

	if multiplayer.has_multiplayer_peer():
		if is_host():
			_broadcast_player_nodes_ready.rpc(local_peer_id)
		else:
			_notify_player_nodes_ready.rpc_id(get_host_peer_id(), local_peer_id)

func host_select_level(level_key: String) -> void:
	if not is_host():
		return

	if SessionState.selected_level_key == level_key:
		status_changed.emit("That level is already selected.")
		return

	var peers_to_return: Array[int] = []
	for peer_id_variant in SessionState.players.keys():
		var peer_id: int = int(peer_id_variant)
		if SessionState.get_player_zone(peer_id) == "level":
			peers_to_return.append(peer_id)

	for peer_id in peers_to_return:
		SessionState.set_player_zone(peer_id, "holding_room")

	if multiplayer.has_multiplayer_peer():
		for peer_id in peers_to_return:
			_move_player_zone.rpc(peer_id, "holding_room")

	SessionState.set_selected_level(level_key, false)

	if steam_available and lobby_id != 0:
		Steam.setLobbyData(lobby_id, LOBBY_SELECTED_LEVEL_KEY, level_key)
		Steam.setLobbyData(lobby_id, LOBBY_LEVEL_OPEN_KEY, "0")

	if multiplayer.has_multiplayer_peer():
		_sync_selected_level.rpc(level_key, false)

	status_changed.emit("Map selected. Host enters first to open the level.")

func request_enter_selected_level(peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	if is_host():
		_enter_selected_level_for_peer(peer_id)
	elif peer_id == get_local_peer_id():
		_request_enter_selected_level.rpc_id(get_host_peer_id())

func request_return_to_holding_room(peer_id: int) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	if is_host():
		_return_peer_to_holding_room(peer_id)
	elif peer_id == get_local_peer_id():
		_request_return_to_holding_room.rpc_id(get_host_peer_id())

func _steam_peer_supported() -> bool:
	return ClassDB.class_exists("SteamMultiplayerPeer")

func _create_steam_host_peer() -> bool:
	if not _steam_peer_supported():
		status_changed.emit("SteamMultiplayerPeer class not found in this editor build.")
		return false

	_shutdown_peer()
	var steam_peer = ClassDB.instantiate("SteamMultiplayerPeer")
	if steam_peer == null:
		status_changed.emit("Could not instantiate SteamMultiplayerPeer.")
		return false

	if Steam.has_method("allowP2PPacketRelay"):
		Steam.allowP2PPacketRelay(true)

	var err = ERR_CANT_CREATE
	if steam_peer.has_method("create_host"):
		err = steam_peer.call("create_host", 0)

	if typeof(err) != TYPE_INT or int(err) != OK:
		status_changed.emit("Steam host peer creation failed: %s" % str(err))
		return false

	peer = steam_peer
	multiplayer.multiplayer_peer = peer
	return true

func _create_steam_client_peer() -> bool:
	if not _steam_peer_supported():
		status_changed.emit("SteamMultiplayerPeer class not found in this editor build.")
		return false

	_shutdown_peer()
	var steam_peer = ClassDB.instantiate("SteamMultiplayerPeer")
	if steam_peer == null:
		status_changed.emit("Could not instantiate SteamMultiplayerPeer.")
		return false

	if Steam.has_method("allowP2PPacketRelay"):
		Steam.allowP2PPacketRelay(true)

	var err = ERR_CANT_CREATE
	if steam_peer.has_method("create_client"):
		err = steam_peer.call("create_client", host_steam_id)

	if typeof(err) != TYPE_INT or int(err) != OK:
		status_changed.emit("Steam client peer creation failed: %s" % str(err))
		return false

	peer = steam_peer
	multiplayer.multiplayer_peer = peer
	return true

func _reset_session() -> void:
	_shutdown_peer()
	SessionState.reset()
	is_current_host = false
	player_nodes_ready_peers.clear()
	sync_gate_changed.emit()
	lobby_id = 0
	host_steam_id = 0
	pending_lobby_join = false
	available_lobbies.clear()
	lobby_list_updated.emit(available_lobbies)

func _reset_sync_gate_for_current_roster() -> void:
	player_nodes_ready_peers.clear()
	for peer_id_variant in SessionState.players.keys():
		var peer_id: int = int(peer_id_variant)
		player_nodes_ready_peers[peer_id] = false
	sync_gate_changed.emit()

func _shutdown_peer() -> void:
	if peer != null and peer.has_method("close"):
		peer.close()
	peer = null
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _on_lobby_created(connect_result: int, created_lobby_id: int) -> void:
	if connect_result != 1:
		status_changed.emit("Steam lobby creation failed.")
		return

	lobby_id = created_lobby_id
	host_steam_id = local_steam_id
	is_current_host = true

	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, LOBBY_NAME_KEY, "%s's Lobby" % local_persona_name)
	Steam.setLobbyData(lobby_id, LOBBY_OWNER_KEY, str(local_steam_id))
	Steam.setLobbyData(lobby_id, LOBBY_VERSION_KEY, GAME_VERSION)
	Steam.setLobbyData(lobby_id, LOBBY_SELECTED_LEVEL_KEY, "")
	Steam.setLobbyData(lobby_id, LOBBY_LEVEL_OPEN_KEY, "0")

	if not _create_steam_host_peer():
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
		host_steam_id = 0
		is_current_host = false
		status_changed.emit("Steam lobby was created, but Steam peer creation failed. Session was not started.")
		return

	SessionState.set_session_active(true)
	var local_peer_id: int = multiplayer.get_unique_id()
	SessionState.ensure_player(local_peer_id, local_persona_name, local_steam_id)
	SessionState.set_player_zone(local_peer_id, "holding_room")
	_reset_sync_gate_for_current_roster()
	_request_lobby_metadata_once([lobby_id])
	_rebuild_available_lobbies_from_ids([lobby_id])
	session_started.emit(true)
	status_changed.emit("Steam lobby created. Invite friends or refresh the lobby list on another instance.")

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		status_changed.emit("Failed to join lobby. Response: %s" % str(response))
		return

	if is_current_host and lobby_id != 0 and joined_lobby_id == lobby_id and host_steam_id == local_steam_id:
		status_changed.emit("Steam lobby ready. Invite friends or refresh the lobby list on another instance.")
		return

	lobby_id = joined_lobby_id
	host_steam_id = int(Steam.getLobbyData(lobby_id, LOBBY_OWNER_KEY))
	if host_steam_id <= 0:
		host_steam_id = int(Steam.getLobbyOwner(lobby_id))
	is_current_host = false

	if not _create_steam_client_peer():
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
		host_steam_id = 0
		status_changed.emit("Joined Steam lobby, but Steam peer creation failed. Left the lobby.")
		return

	SessionState.reset()
	pending_lobby_join = true
	_reset_sync_gate_for_current_roster()
	_request_lobby_metadata_once([lobby_id])
	_rebuild_available_lobbies_from_ids([lobby_id])
	status_changed.emit("Joined Steam lobby. Waiting for host connection...")

func _on_lobby_match_list(match_result = null) -> void:
	var lobby_ids: Array = _extract_lobby_ids_from_match_result(match_result)
	_request_lobby_metadata_once(lobby_ids)
	_rebuild_available_lobbies_from_ids(lobby_ids)
	status_changed.emit("Found %d matching Steam lobbies." % available_lobbies.size())

func _on_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	if steam_available:
		status_changed.emit("Steam join request received.")
		Steam.joinLobby(requested_lobby_id)

func _on_game_lobby_join_requested(requested_lobby_id: int, _friend_id: int) -> void:
	if steam_available:
		status_changed.emit("Steam game lobby join request received.")
		Steam.joinLobby(requested_lobby_id)

func _on_lobby_chat_update(_changed_lobby_id: int, _changed_user: int, _making_change_user: int, _chat_state: int) -> void:
	pass

func _on_lobby_data_update(success: int, changed_lobby_id: int, _member_id: int) -> void:
	if success != 1:
		return

	_rebuild_available_lobbies_from_ids(_current_visible_lobby_ids())

	if changed_lobby_id == lobby_id and steam_available:
		var selected = str(Steam.getLobbyData(lobby_id, LOBBY_SELECTED_LEVEL_KEY))
		var open = str(Steam.getLobbyData(lobby_id, LOBBY_LEVEL_OPEN_KEY)) == "1"
		if selected != SessionState.selected_level_key or open != SessionState.level_open:
			SessionState.set_selected_level(selected, open)

func _on_peer_connected(id: int) -> void:
	if not is_host():
		return

	for peer_id_variant in SessionState.players.keys():
		var peer_id: int = int(peer_id_variant)
		var info: Dictionary = SessionState.players[peer_id]
		_register_player.rpc_id(
			id,
			peer_id,
			str(info.get("name", "Player")),
			int(info.get("steam_id", 0)),
			str(info.get("zone", "holding_room"))
		)

	_sync_selected_level.rpc_id(id, SessionState.selected_level_key, SessionState.level_open)
	status_changed.emit("Peer connected: %s" % id)

func _on_peer_disconnected(id: int) -> void:
	SessionState.remove_player(id)
	if is_host() and multiplayer.has_multiplayer_peer():
		_remove_player_registry.rpc(id)
	_reset_sync_gate_for_current_roster()
	status_changed.emit("Peer disconnected: %s" % id)

func _on_connected_to_server() -> void:
	pending_lobby_join = false
	SessionState.set_session_active(true)
	if steam_available and lobby_id != 0:
		SessionState.set_selected_level(
			str(Steam.getLobbyData(lobby_id, LOBBY_SELECTED_LEVEL_KEY)),
			str(Steam.getLobbyData(lobby_id, LOBBY_LEVEL_OPEN_KEY)) == "1"
		)
	status_changed.emit("Connected to host. Registering local player...")
	_submit_local_identity.rpc_id(get_host_peer_id(), get_local_display_name(), local_steam_id)
	session_started.emit(false)

func _on_connection_failed() -> void:
	if steam_available and lobby_id != 0 and pending_lobby_join:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
		host_steam_id = 0
		pending_lobby_join = false
	status_changed.emit("Connection failed.")

func _on_server_disconnected() -> void:
	status_changed.emit("Host disconnected.")
	_shutdown_peer()
	if steam_available and lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0
		host_steam_id = 0
	pending_lobby_join = false
	SessionState.reset()
	player_nodes_ready_peers.clear()
	sync_gate_changed.emit()

@rpc("authority", "reliable")
func _register_player(peer_id: int, player_name: String, player_steam_id: int, zone: String) -> void:
	SessionState.ensure_player(peer_id, player_name, player_steam_id)
	SessionState.set_player_zone(peer_id, zone)
	_reset_sync_gate_for_current_roster()

@rpc("authority", "reliable")
func _remove_player_registry(peer_id: int) -> void:
	SessionState.remove_player(peer_id)
	_reset_sync_gate_for_current_roster()

@rpc("any_peer", "reliable")
func _submit_local_identity(player_name: String, player_steam_id: int) -> void:
	if not is_host():
		return

	var sender = multiplayer.get_remote_sender_id()
	SessionState.ensure_player(sender, player_name, player_steam_id)
	SessionState.set_player_zone(sender, "holding_room")
	_reset_sync_gate_for_current_roster()

	for peer_id_variant in SessionState.players.keys():
		var peer_id: int = int(peer_id_variant)
		var info: Dictionary = SessionState.players[peer_id]
		_register_player.rpc_id(
			sender,
			peer_id,
			str(info.get("name", "Player")),
			int(info.get("steam_id", 0)),
			str(info.get("zone", "holding_room"))
		)

	_register_player.rpc(sender, player_name, player_steam_id, "holding_room")
	_sync_selected_level.rpc_id(sender, SessionState.selected_level_key, SessionState.level_open)
	status_changed.emit("%s joined the party." % player_name)

@rpc("any_peer", "reliable")
func _notify_player_nodes_ready(peer_id: int) -> void:
	if not is_host():
		return

	var sender = multiplayer.get_remote_sender_id()
	if peer_id != sender:
		peer_id = sender

	player_nodes_ready_peers[peer_id] = true
	_broadcast_player_nodes_ready.rpc(peer_id)
	sync_gate_changed.emit()

@rpc("authority", "reliable")
func _broadcast_player_nodes_ready(peer_id: int) -> void:
	player_nodes_ready_peers[peer_id] = true
	sync_gate_changed.emit()

@rpc("authority", "reliable")
func _sync_selected_level(level_key: String, open: bool) -> void:
	SessionState.set_selected_level(level_key, open)

@rpc("any_peer", "reliable")
func _request_enter_selected_level() -> void:
	if not is_host():
		return
	var sender = multiplayer.get_remote_sender_id()
	_enter_selected_level_for_peer(sender)

func _enter_selected_level_for_peer(peer_id: int) -> void:
	if SessionState.selected_level_key.is_empty():
		status_changed.emit("No level selected.")
		return

	if not SessionState.level_open:
		if peer_id == get_host_peer_id():
			SessionState.set_level_open(true)
			if steam_available and lobby_id != 0:
				Steam.setLobbyData(lobby_id, LOBBY_LEVEL_OPEN_KEY, "1")
			_sync_selected_level.rpc(SessionState.selected_level_key, true)
			status_changed.emit("Host opened the level.")
		else:
			status_changed.emit("Host has not opened the level yet.")
			return

	SessionState.set_player_zone(peer_id, "level")
	_move_player_zone.rpc(peer_id, "level")

@rpc("any_peer", "reliable")
func _request_return_to_holding_room() -> void:
	if not is_host():
		return
	var sender = multiplayer.get_remote_sender_id()
	_return_peer_to_holding_room(sender)

func _return_peer_to_holding_room(peer_id: int) -> void:
	SessionState.set_player_zone(peer_id, "holding_room")
	_move_player_zone.rpc(peer_id, "holding_room")

@rpc("authority", "reliable")
func _move_player_zone(peer_id: int, zone: String) -> void:
	SessionState.set_player_zone(peer_id, zone)

@rpc("authority", "reliable")
func _notify_session_closed(reason: String) -> void:
	status_changed.emit(reason)