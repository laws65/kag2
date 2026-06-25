extends Node


signal server_started

var _unregistered_peers: Array[UnregisteredPeer]

var client_join_data_validator: Callable = func(join_data: Dictionary): return true

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
	_unregistered_peers.push_back(UnregisteredPeer.new(player_id))
	_transmit_initial_state_to(player_id)


func _on_peer_disconnected(player_id: int) -> void:
	print("Peer ", player_id, " has disconnected")

	UnregisteredPeer.erase_peer(player_id, _unregistered_peers)

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

	var gamemode_path := GamemodeManager.get_current_gamemode().resource_path
	var gamemode_data := GamemodeManager.get_gamemode_data()

	var map_path := MapManager.get_current_map().scene_file_path
	var map_data := MapManager.get_current_map().get_spawn_data()

	var initial_state := {
		"players": serialised_players,
		"blobs": blob_data,
		"time_ticks": NetworkedClock.time_ticks,
		"gamemode_path": gamemode_path,
		"gamemode_data": gamemode_data,
		"map_path": map_path,
		"map_data": map_data,
	}

	Client.receive_initial_state.rpc_id(player_id, initial_state)


@rpc("any_peer", "reliable")
func receive_client_join_data(join_data: Dictionary) -> void:
	var player_id := multiplayer.get_remote_sender_id()
	var unregistered_peer := UnregisteredPeer.get_peer(player_id, _unregistered_peers)

	if not is_instance_valid(unregistered_peer):
		print("Client %s is trying to mess us up" % player_id)
		return

	unregistered_peer.spawn_data = join_data

	if not client_join_data_validator.call(join_data):
		print("Player data is invalid! Closing connection")
		kick_player(player_id, "Invalid join data")

		UnregisteredPeer.erase_peer(player_id, _unregistered_peers)
		return

	if unregistered_peer.is_loaded:
		_spawn_new_player(player_id)


@rpc("any_peer", "reliable")
func client_finished_loading() -> void:
	var player_id := multiplayer.get_remote_sender_id()
	var unregistered_peer := UnregisteredPeer.get_peer(player_id, _unregistered_peers)
	if is_instance_valid(unregistered_peer):
		unregistered_peer.is_loaded = true
	else:
		print("Client %s is trying to mess us up" % player_id)
		return

	if client_join_data_validator.call(unregistered_peer.spawn_data):
		_spawn_new_player(player_id)


func kick_player(player_id: int, reason: String) -> void:
	Client.receive_server_kick.rpc_id(player_id, reason)

	var force_kick_timeout_time := 5.0
	await get_tree().create_timer(force_kick_timeout_time).timeout
	if player_id in multiplayer.get_peers():
		multiplayer.disconnect_peer(player_id)


func _spawn_new_player(player_id: int) -> void:
	var join_data := UnregisteredPeer.get_peer(player_id, _unregistered_peers).spawn_data

	Client.prepare_to_spawn_in.rpc_id(player_id, NetworkedClock.time_ticks)

	Network.rpc_id_safe(0, Players.register_player, player_id, join_data)

	UnregisteredPeer.erase_peer(player_id, _unregistered_peers)


func _load_server_config() -> void:
	var config_path := "res://server_config.tres"
	var new_config: ServerConfig = load(config_path) # TODO add error checking, add custom cfg in user:// maybe
	config = new_config
