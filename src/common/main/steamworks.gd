extends Node


const APP_ID: int = 480


func initialise_on_client() -> void:
	var initialise_response := Steam.steamInitEx(APP_ID, true)

	if initialise_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialise_response)
		get_tree().quit()


func initialise_on_server(ip: String, port: int, query_port: int, server_mode: SteamServer.ServerMode, version: String) -> void:
	var initialise_response := SteamServer.serverInitEx(ip, port, query_port, server_mode, version)
	print(initialise_response)
