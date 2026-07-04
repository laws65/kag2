extends RefCounted
class_name SteamServerBrowser


signal query_response(server_details: Dictionary)
signal query_finished(response: int)


func _init() -> void:
	SteamServer.server_connected.connect(_register_server_on_server_browser)
	Steam.request_server_list_refresh_complete.connect(_on_server_list_request_refresh_complete)
	Steam.request_server_list_server_failed_to_respond.connect(_on_server_list_request_server_failed_to_respond)
	Steam.request_server_list_server_responded.connect(_on_server_list_request_server_responded)



func _register_server_on_server_browser() -> void:
	SteamServer.setServerName(Server.config.sv_name)
	SteamServer.setMapName(MapManager.get_current_map().name)
	SteamServer.setMaxPlayerCount(Server.config.max_players)
	SteamServer.setPasswordProtected(Server.config.sv_password != "")
	SteamServer.setDedicatedServer(true)

	if Server.config.display_in_server_browser:
		SteamServer.setAdvertiseServerActive(true)


func request_server_list(filters: Array) -> int:
	# https://partner.steamgames.com/doc/api/ISteamMatchmakingServers#MatchMakingKeyValuePair_t
	var old_request_id := Steam.get_server_list_request()
	Steam.cancelQuery(old_request_id)
	Steam.releaseRequest(old_request_id)

	var request_id: int = Steam.requestInternetServerList(Steam.getAppID(), filters)
	if request_id <= 0:
		print("Request for server list failed, probably haven't initialised steam")
	return request_id


# TODO figure out what the response is for this in terms of enum values
func _on_server_list_request_refresh_complete(request_id: int, response: int) -> void:
	print("Request complete with handle %s and id %s" % [request_id, response])
	query_finished.emit(response)

	match response:
		Steam.MatchMakingServerResponse.SERVER_RESPONDED:
			pass
		Steam.MatchMakingServerResponse.SERVER_FAILED_TO_RESPOND:
			print("Server failed to respond to server list request")
		Steam.MatchMakingServerResponse.NO_SERVERS_LISTED_ON_MASTER_SERVER:
			print("No server listed")


func _on_server_list_request_server_failed_to_respond(request_id: int, server_index: int) -> void:
	print("Request failed to respond with handle %s and id %s" % [request_id, server_index])
	var server_details: Dictionary = Steam.getServerDetails(server_index, request_id)
	query_response.emit(server_details)


func _on_server_list_request_server_responded(request_id: int, server_index: int) -> void:
	print("Request responded with handle %s and id %s" % [request_id, server_index])
	var server_details: Dictionary = Steam.getServerDetails(server_index, request_id)
	query_response.emit(server_details)
