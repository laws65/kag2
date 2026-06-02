extends Node


var _unregistered_peers: Array[int]
var _client_join_data: Dictionary[int, Dictionary]


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


func _handle_server_error(err: Error) -> void:
	if err == Error.ERR_ALREADY_IN_USE:
		print("PORT ALREADY IN USE")
	elif err == Error.ERR_CANT_CREATE:
		print("CANT CREATE SERVER")


func _on_peer_connected(player_id: int) -> void:
	print("Peer ", player_id, " has connected")
	_unregistered_peers.push_back(player_id)
	_request_client_join_data(player_id)


func _request_client_join_data(player_id: int) -> void:
	print("Requesting peer ", player_id, "'s join data")
	Client.send_join_data.rpc_id(player_id)


@rpc("any_peer", "reliable")
func receive_client_join_data(join_data: Dictionary) -> void:
	var player_id := multiplayer.get_remote_sender_id()
	print("Join data received from player ", player_id)
	var username: String = join_data["username"]
	var colour: Color = join_data["colour"]
	print("Player's username is ", username)
	print("Player's colour is ", colour)

	if _client_allowed_to_join(player_id, join_data):
		_client_join_data[player_id] = join_data
		_transmit_initial_state_to(player_id)
	else:
		print("Player data is invalid! Closing connection")
		_unregistered_peers.erase(player_id)
		_client_join_data.erase(player_id)
		kick_player(player_id, "Invalid join data")


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
	}
	Client.receive_initial_state.rpc_id(player_id, initial_state)


@rpc("any_peer", "reliable")
func client_finished_loading() -> void:
	var player_id := multiplayer.get_remote_sender_id()
	var join_data: Dictionary = _client_join_data[player_id]
	_unregistered_peers.erase(player_id)
	_client_join_data.erase(player_id)
	register_player(player_id, join_data)


func kick_player(player_id: int, reason: String) -> void:
	Client.receive_server_kick.rpc_id(player_id, reason)

	var force_kick_timeout_time := 5.0
	await get_tree().create_timer(force_kick_timeout_time).timeout
	if player_id in multiplayer.get_peers():
		multiplayer.disconnect_peer(player_id)


func _client_allowed_to_join(player_id: int, join_data: Dictionary) -> bool:
	return player_id in _unregistered_peers and _join_data_valid(join_data)


func _join_data_valid(join_data: Dictionary) -> bool:
	return client_join_data_validator.call(join_data)


func _on_peer_disconnected(player_id: int) -> void:
	print("Peer ", player_id, " has disconnected")
	_unregistered_peers.erase(player_id)
	_client_join_data.erase(player_id)
	deregister_player(player_id)


func register_player(player_id: int, extra_data: Dictionary) -> void:
	assert(multiplayer.is_server())
	Players.register_player.rpc_id(0, player_id, extra_data)


func deregister_player(player_id: int) -> void:
	assert(multiplayer.is_server())
	Players.deregister_player.rpc_id(0, player_id)
