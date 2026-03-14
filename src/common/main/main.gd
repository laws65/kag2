extends Node


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--server" in args:
		Server.start_server()
	elif "--client" in args:
		Client.join_server()
