extends Node


var startup_immediately = true


func _ready() -> void:
	Blobs.set_blobs_parent(get_node("World/Blobs"))
	MapManager.set_map_parent(get_node("World/MapParent"))
	Client.custom_join_data["username"] = "hello"
	Server.connection_requested.connect(_authorise_new_player)
	var args := OS.get_cmdline_args()
	if "--server" in args:
		Server.start_server()
	elif startup_immediately and "--client" in args:
		Client.join_server()
	else:
		Steamworks._initialise_on_client()

	if not Server.custom_client_authenticator.is_valid():
		Server.custom_client_authenticator = _authorise_new_player


func _authorise_new_player(player_id: int, join_data: Dictionary) -> void:
	if join_data.has("username") and join_data["username"] != "":
		Server.accept_connection_request(player_id)
	else:
		Server.reject_connection_request(player_id, "You don't have a username")
