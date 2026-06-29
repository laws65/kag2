extends Node


signal connection_established
signal joined_server
signal left_server

var custom_join_data: Dictionary


func _ready() -> void:
	Players.new_player_joined.connect(_on_Player_joined)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_Player_joined(player: Player) -> void:
	if player.is_my_player():
		NetworkedClock.enable_on_client()
		joined_server.emit()


func join_server(address: String="localhost", port: int=50302) -> void:
	var peer := ENetMultiplayerPeer.new()

	var err := peer.create_client(address, port)
	if err:
		_handle_join_error(err)
		return

	Network.buffer_incoming_rpcs = true

	multiplayer.set_multiplayer_peer(peer)


func _handle_join_error(err: Error) -> void:
	if err == Error.ERR_ALREADY_IN_USE:
		print("CLIENT ALREADY CONNECTED")
	elif err == Error.ERR_CANT_CREATE:
		print("CANT CREATE CLIENT")


func _on_connected_to_server() -> void:
	NetworkedClock.initialise_on_client()
	connection_established.emit()
	Server.receive_client_join_data.rpc_id(1, custom_join_data)
	print("Successfully connected to server")


func _on_connection_failed() -> void:
	print("Failed to connect to server")


func _on_server_disconnected() -> void:
	print("Server disconnected")
	left_server.emit()
	NetworkedClock.shutdown_on_client()
	Network.reset()
	Blobs.reset()
	Players.reset()
	SyncManager.reset()


@rpc("authority", "reliable")
func receive_server_kick(reason: String) -> void:
	print("Kicked from server for reason: ", reason)
	multiplayer.multiplayer_peer.close()


@rpc("authority", "reliable")
func receive_initial_state(initial_state: Dictionary) -> void:
	SyncManager.set_complete_world_state(initial_state)
	Server.client_finished_loading.rpc_id(1)


@rpc("authority", "reliable")
func prepare_to_spawn_in(server_transmit_time_ticks: int) -> void:
	Network.buffer_incoming_rpcs = false
	Network.accept_rpcs_after_time_ticks = server_transmit_time_ticks


func disconnect_from_server() -> void:
	multiplayer.multiplayer_peer.close()
