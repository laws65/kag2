extends Node


var custom_client_join_data_validator = func(data: Dictionary):
	return data.has("username") and data["username"] != ""

var startup_immediately = true


func _ready() -> void:
	Blobs.set_blobs_parent(get_node("World/Blobs"))
	Server.client_join_data_validator = custom_client_join_data_validator

	if startup_immediately:
		var args := OS.get_cmdline_args()
		if "--server" in args:
			Server.start_server()
		elif "--client" in args:
			Client.join_server()
