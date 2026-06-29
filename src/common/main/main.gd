extends Node


var startup_immediately = true


func _ready() -> void:
	Blobs.set_blobs_parent(get_node("World/Blobs"))
	MapManager.set_map_parent(get_node("World/MapParent"))
	Client.custom_join_data = {"username": "hello"}
	Server.connection_requested.connect(_authorise_new_player)
	if startup_immediately:
		var args := OS.get_cmdline_args()
		if "--server" in args:
			Server.start_server()
		elif "--client" in args:
			Client.join_server()


func _authorise_new_player(player_id: int, join_data: Dictionary) -> void:
	if join_data.has("username") and join_data["username"] != "":
		Server.accept_connection_request(player_id)
	else:
		Server.reject_connection_request(player_id, "You are not cool enough")
