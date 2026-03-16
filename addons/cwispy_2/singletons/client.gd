extends Node


var get_join_data_callable: Callable


func join_server(address: String="localhost", port: int=50301) -> void:
	var peer := ENetMultiplayerPeer.new()
	
	var err := peer.create_client(address, port)
	if err:
		_handle_join_error(err)
		return
	
	multiplayer.set_multiplayer_peer(peer)
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _handle_join_error(err: Error) -> void:
	if err == Error.ERR_ALREADY_IN_USE:
		print("CLIENT ALREADY CONNECTED")
	elif err == Error.ERR_CANT_CREATE:
		print("CANT CREATE CLIENT")


func _on_connected_to_server() -> void:
	print("Successfully connected to server")


func _on_connection_failed() -> void:
	print("Failed to connect to server")


func _on_server_disconnected() -> void:
	print("Server disconnected")


@rpc("authority", "reliable")
func send_join_data() -> void:
	assert(get_join_data_callable, "Developer must set Client.get_join_data_callable!")
	var join_data := get_join_data_callable.call()
	Server.receive_client_join_data.rpc_id(1, join_data)


@rpc("authority", "reliable")
func receive_server_kick(reason: String) -> void:
	print("Kicked from server for reason: ", reason)
	multiplayer.multiplayer_peer.close()


@rpc("authority", "reliable")
func receive_initial_state(serialised_players: Array[PackedByteArray]) -> void:
	for serialised_player in serialised_players:
		var deserialised_player := Player.deserialise(serialised_player)
		Players.add_old_player(deserialised_player)
	
	Server.client_finished_loading.rpc_id(1)
