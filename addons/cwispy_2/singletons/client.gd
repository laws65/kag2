extends Node


signal connection_established
signal joined_server

var has_joined_server: bool = false

var get_join_data_callable: Callable
var spawn_time := -1


func _ready() -> void:
	Players.new_player_joined.connect(_on_Player_joined)


func _on_Player_joined(player: Player) -> void:
	if player.is_my_player():
		has_joined_server = true
		NetworkedClock.enable_on_client()
		joined_server.emit()


func join_server(address: String="localhost", port: int=50301) -> void:

	var peer := ENetMultiplayerPeer.new()

	var err := peer.create_client(address, port)
	if err:
		_handle_join_error(err)
		return

	Network.buffer_incoming_rpcs = true

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
	NetworkedClock.initialise_on_client()
	connection_established.emit()
	_transmit_join_data()
	print("Successfully connected to server")


func _on_connection_failed() -> void:
	print("Failed to connect to server")


func _on_server_disconnected() -> void:
	print("Server disconnected")


func _transmit_join_data() -> void:
	assert(get_join_data_callable, "Developer must set Client.get_join_data_callable!")
	var join_data := get_join_data_callable.call()
	Server.receive_client_join_data.rpc_id(1, join_data)


@rpc("authority", "reliable")
func receive_server_kick(reason: String) -> void:
	print("Kicked from server for reason: ", reason)
	multiplayer.multiplayer_peer.close()


@rpc("authority", "reliable")
func receive_initial_state(initial_state: Dictionary) -> void:
	var serialised_players: Array[PackedByteArray] = initial_state["players"]
	for serialised_player in serialised_players:
		var deserialised_player := Player.deserialise(serialised_player)
		print("adding old player")
		Players.add_old_player(deserialised_player)

	var blobs: Array[Dictionary] = initial_state["blobs"]
	for blob in blobs:
		var filepath: String = blob["filepath"]
		var spawn_data: Dictionary = blob["spawn_data"]
		Blobs._create_blob(filepath, spawn_data)

	spawn_time = initial_state["time_ticks"]
	Network.buffer_cull_before_time_ticks = initial_state["time_ticks"] # reject rpcs sent before world state

	print("Telling server im done loading")
	Server.client_finished_loading.rpc_id(1)


@rpc("authority", "reliable")
func prepare_to_spawn_in(server_transmit_time_ticks: int) -> void:
	print("I have been told to prepare to spawn in, buffer time is %s" % server_transmit_time_ticks)
	Network.buffer_incoming_rpcs = false
	Network.accept_rpcs_after_time_ticks = server_transmit_time_ticks


func get_my_id() -> int:
	return multiplayer.get_unique_id()


func get_my_player() -> Player:
	return Players.get_player_by_id(get_my_id())


func has_blob() -> bool:
	return get_my_player().has_blob()


func get_my_blob() -> Blob:
	return get_my_player().get_blob()


func get_my_blob_id() -> int:
	return get_my_player().get_blob_id()
