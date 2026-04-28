extends Node

signal player_registry_changed()
signal player_zone_changed(peer_id: int, zone: String)
signal selected_level_changed()
signal session_state_changed()

var players: Dictionary = {}
var selected_level_key: String = ""
var level_open: bool = false
var session_active: bool = false

func reset() -> void:
	players.clear()
	selected_level_key = ""
	level_open = false
	session_active = false
	player_registry_changed.emit()
	selected_level_changed.emit()
	session_state_changed.emit()

func set_session_active(active: bool) -> void:
	session_active = active
	session_state_changed.emit()

func ensure_player(peer_id: int, player_name: String, steam_id: int = 0) -> void:
	var zone = "holding_room"
	if players.has(peer_id):
		zone = str(players[peer_id].get("zone", "holding_room"))
	players[peer_id] = {
		"name": player_name,
		"steam_id": steam_id,
		"zone": zone,
	}
	player_registry_changed.emit()

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)
	player_registry_changed.emit()

func set_player_zone(peer_id: int, zone: String) -> void:
	if not players.has(peer_id):
		ensure_player(peer_id, "Player", 0)
	players[peer_id]["zone"] = zone
	player_zone_changed.emit(peer_id, zone)
	player_registry_changed.emit()

func get_player_name(peer_id: int) -> String:
	return str(players.get(peer_id, {}).get("name", "Player"))

func get_player_zone(peer_id: int) -> String:
	return str(players.get(peer_id, {}).get("zone", "holding_room"))

func set_selected_level(level_key: String, open: bool) -> void:
	selected_level_key = level_key
	level_open = open
	selected_level_changed.emit()

func set_level_open(open: bool) -> void:
	level_open = open
	selected_level_changed.emit()