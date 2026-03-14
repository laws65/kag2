extends Node


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


func _on_peer_connected(peer_id: int) -> void:
	print("Peer ", peer_id, " has connected")


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer ", peer_id, " has disconnected")
