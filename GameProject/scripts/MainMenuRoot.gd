extends Control

@onready var status_label: Label = $RootMargin/RootHBox/MenuPanel/MenuVBox/StatusLabel
@onready var refresh_button: Button = $RootMargin/RootHBox/LobbyPanel/LobbyVBox/RefreshButton
@onready var lobby_list_vbox: VBoxContainer = $RootMargin/RootHBox/LobbyPanel/LobbyVBox/ScrollContainer/LobbyListVBox

func _ready() -> void:
	SteamNet.status_changed.connect(_on_status_changed)
	SteamNet.lobby_list_updated.connect(_rebuild_lobby_list)
	lobby_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_list_vbox.custom_minimum_size = Vector2(360, 0)
	_on_status_changed("Ready.")
	_rebuild_lobby_list([])

func _on_status_changed(text: String) -> void:
	status_label.text = text
	refresh_button.disabled = not SteamNet.steam_available

func _clear_lobby_rows() -> void:
	for child in lobby_list_vbox.get_children():
		child.queue_free()

func _rebuild_lobby_list(lobbies: Array) -> void:
	_clear_lobby_rows()
	if lobbies.is_empty():
		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(340, 0)
		label.text = "No lobbies found. Only lobbies with your Steam friends in them are shown."
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		lobby_list_vbox.add_child(label)
		return

	for lobby in lobbies:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(280, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s\nMembers: %s" % [str(lobby.get("name", "Lobby")), str(lobby.get("members", 0))]
		row.add_child(label)

		var join_button = Button.new()
		join_button.text = "Join"
		join_button.pressed.connect(_on_join_lobby_pressed.bind(int(lobby.get("lobby_id", 0))))
		row.add_child(join_button)

		lobby_list_vbox.add_child(row)

func _on_join_lobby_pressed(target_lobby_id: int) -> void:
	SteamNet.join_lobby_by_id(target_lobby_id)

func _on_steam_host_pressed() -> void:
	SteamNet.start_steam_host_session()

func _on_demo_host_pressed() -> void:
	SteamNet.start_demo_host_session()

func _on_demo_join_pressed() -> void:
	SteamNet.start_demo_joined_session()

func _on_refresh_pressed() -> void:
	SteamNet.request_lobby_list()

func _on_leave_pressed() -> void:
	SteamNet.leave_session()