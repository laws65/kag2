extends Node


signal server_started
signal connection_requested(peer_id: int, join_data: Dictionary)

var _client_join_data: Dictionary[int, Dictionary]

var config: ServerConfig


func start_server() -> void:
	_load_server_config()

	var peer := ENetMultiplayerPeer.new()

	var err := peer.create_server(config.sv_port)
	if err:
		_handle_server_error(err)
		return

	multiplayer.set_multiplayer_peer(peer)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	GamemodeManager.server_load_gamemode(config.gamemode_path)

	NetworkedClock.enable_on_server()

	server_started.emit()


func _handle_server_error(err: Error) -> void:
	if err == Error.ERR_ALREADY_IN_USE:
		print("PORT ALREADY IN USE")
	elif err == Error.ERR_CANT_CREATE:
		print("CANT CREATE SERVER")


func _on_peer_connected(player_id: int) -> void:
	print("Peer ", player_id, " has connected")
	_client_join_data[player_id] = {}


func _on_peer_disconnected(player_id: int) -> void:
	print("Peer ", player_id, " has disconnected")

	_client_join_data.erase(player_id)

	Players.deregister_player.rpc(player_id)


@rpc("any_peer", "reliable")
func receive_client_join_data(join_data: Dictionary) -> void:
	var player_id := multiplayer.get_remote_sender_id()

	if not player_id in _client_join_data.keys():
		print("Client %s is trying to mess us up" % player_id)
		return

	_client_join_data[player_id] = join_data
	connection_requested.emit(player_id, join_data)


func accept_connection_request(player_id: int) -> void:
	var initial_state: Dictionary = SyncManager.get_complete_world_state()
	Client.receive_initial_state.rpc_id(player_id, initial_state)


func reject_connection_request(player_id: int, msg: String) -> void:
	kick_player(player_id, msg)


@rpc("any_peer", "reliable")
func client_finished_loading() -> void:
	var player_id := multiplayer.get_remote_sender_id()

	if not player_id in _client_join_data.keys():
		print("Client %s is trying to mess us up" % player_id)
		return

	_spawn_new_player(player_id)


func kick_player(player_id: int, reason: String) -> void:
	_client_join_data.erase(player_id)
	Client.receive_server_kick.rpc_id(player_id, reason)

	var force_kick_timeout_time := 5.0
	await get_tree().create_timer(force_kick_timeout_time).timeout
	if player_id in multiplayer.get_peers():
		multiplayer.disconnect_peer(player_id)


func _spawn_new_player(player_id: int) -> void:
	var join_data := _client_join_data[player_id]

	Client.prepare_to_spawn_in.rpc_id(player_id, NetworkedClock.time_ticks)

	Network.rpc_id_safe(0, Players.register_player, player_id, join_data)

	_client_join_data.erase(player_id)


func _load_server_config() -> void:
	var config_path := "res://server_config.tres"
	var new_config: ServerConfig = load(config_path) # TODO add error checking, add custom cfg in user:// maybe
	config = new_config
