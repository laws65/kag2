extends Node


signal server_started

var _unregistered_peers: Array[int]
var _client_join_data: Dictionary[int, Dictionary]
var _loaded_new_peers: Array[int]

var client_join_data_validator: Callable = func(join_data: Dictionary): return true


func start_server(port: int=50301) -> void:
	var peer := ENetMultiplayerPeer.new()

	var err := peer.create_server(port)
	if err:
		_handle_server_error(err)
		return

	multiplayer.set_multiplayer_peer(peer)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	NetworkedClock.enable_on_server()

	server_started.emit()


func _handle_server_error(err: Error) -> void:
	if err == Error.ERR_ALREADY_IN_USE:
		print("PORT ALREADY IN USE")
	elif err == Error.ERR_CANT_CREATE:
		print("CANT CREATE SERVER")


func _on_peer_connected(player_id: int) -> void:
	print("Peer ", player_id, " has connected")
	_unregistered_peers.push_back(player_id)
	_transmit_initial_state_to(player_id)


func _on_peer_disconnected(player_id: int) -> void:
	print("Peer ", player_id, " has disconnected")
	_unregistered_peers.erase(player_id)
	_client_join_data.erase(player_id)
	_loaded_new_peers.erase(player_id)
	Players.deregister_player.rpc(player_id)


func _transmit_initial_state_to(player_id: int) -> void:
	var serialised_players: Array[PackedByteArray]

	var players := Players.get_players()
	for player in players:
		serialised_players.push_back(player.serialise())

	var blob_data: Array[Dictionary]
	var blobs := Blobs.get_blobs()
	for blob in blobs:
		blob_data.push_back({
			"filepath": blob.scene_file_path,
			"spawn_data": blob.get_spawn_data()
		})

	var initial_state := {
		"players": serialised_players,
		"blobs": blob_data,
		"time_ticks": NetworkedClock.time_ticks,
	}

	Client.receive_initial_state.rpc_id(player_id, initial_state)


@rpc("any_peer", "reliable")
func receive_client_join_data(join_data: Dictionary) -> void:
	var player_id := multiplayer.get_remote_sender_id()
	_client_join_data[player_id] = join_data

	if not _client_join_data_valid(player_id):
		print("Player data is invalid! Closing connection")
		kick_player(player_id, "Invalid join data")

		_unregistered_peers.erase(player_id)
		_loaded_new_peers.erase(player_id)
		_client_join_data.erase(player_id)

	if _can_spawn_new_player(player_id):
		_spawn_new_player(player_id)


@rpc("any_peer", "reliable")
func client_finished_loading() -> void:
	var player_id := multiplayer.get_remote_sender_id()
	_loaded_new_peers.push_back(player_id)

	if _can_spawn_new_player(player_id):
		_spawn_new_player(player_id)


func kick_player(player_id: int, reason: String) -> void:
	Client.receive_server_kick.rpc_id(player_id, reason)

	var force_kick_timeout_time := 5.0
	await get_tree().create_timer(force_kick_timeout_time).timeout
	if player_id in multiplayer.get_peers():
		multiplayer.disconnect_peer(player_id)


func _client_join_data_valid(player_id: int) -> bool:
	return (
		_client_join_data.has(player_id) and
		client_join_data_validator.call(_client_join_data[player_id])
	)


func _can_spawn_new_player(player_id: int) -> bool:
	return (
		_unregistered_peers.has(player_id) and
		_loaded_new_peers.has(player_id) and
		_client_join_data_valid(player_id)
	)


func _spawn_new_player(player_id: int) -> void:
	var join_data := _client_join_data[player_id]

	Client.prepare_to_spawn_in.rpc_id(player_id, NetworkedClock.time_ticks)

	Network.rpc_id_safe(0, Players.register_player, player_id, join_data)

	_unregistered_peers.erase(player_id)
	_loaded_new_peers.erase(player_id)
	_client_join_data.erase(player_id)
