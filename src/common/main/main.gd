extends Node


var startup_immediately = true


func _ready() -> void:
	Blobs.set_blobs_parent(get_node("World/Blobs"))
	MapManager.set_map_parent(get_node("World/MapParent"))
	Client.custom_join_data["username"] = "hello"
	Server.connection_requested.connect(_authorise_new_player)
	if startup_immediately:
		var args := OS.get_cmdline_args()
		if "--server" in args:
			Steamworks.initialise_on_server()
			Server.start_server()
		elif "--client" in args:
			Steamworks.initialise_on_client()
			Client.join_server()


"""
Init steam on client
transmit steam id and auth thingo to server
server will validate it, spawn data of new player will therefore be modified



"""
func _authorise_new_player(player_id: int, join_data: Dictionary) -> void:
	if join_data.has("username") and join_data["username"] != "":
		Steamworks.begin_new_player_authentication(player_id, join_data)
		#Server.accept_connection_request(player_id)
	else:
		Server.reject_connection_request(player_id, "You are not cool enough")
