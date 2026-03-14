extends Node


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
