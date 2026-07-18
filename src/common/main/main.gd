extends Node


var startup_immediately = true


func _ready() -> void:
	var space := get_viewport().world_2d.space
	PhysicsServer2D.space_set_active(space, false)

	NetworkedClock.physics_tick.connect(_on_physics_tick)
	Blobs.set_blobs_parent(get_node("World/Blobs"))
	MapManager.set_map_parent(get_node("World/MapParent"))
	Client.custom_join_data["username"] = "hello"
	Server.connection_requested.connect(_authorise_new_player)
	var args := OS.get_cmdline_args()
	if "--server" in args:
		Server.start_server()
	elif startup_immediately and "--client" in args:
		Client.join_server()


	if not Server.custom_client_authenticator.is_valid():
		Server.custom_client_authenticator = _authorise_new_player


func _authorise_new_player(player_id: int, join_data: Dictionary) -> void:
	if join_data.has("username") and join_data["username"] != "":
		Server.accept_connection_request(player_id)
	else:
		Server.reject_connection_request(player_id, "You don't have a username")


func _on_physics_tick() -> void:
	var space := get_viewport().world_2d.space
	RapierPhysicsServer2D.space_step(space, NetworkedClock.tick_duration_msecs / 1000.0)
	RapierPhysicsServer2D.space_flush_queries(space)
