extends RefCounted
class_name SteamServerBrowser


signal query_response(server_details: Dictionary)
signal query_finished(response: int)


enum Target {
	NONE = -1,
	INTERNET = 0,
	FAVOURITES = 1,
	FRIENDS = 2,
	HISTORY = 3,
}


func _init() -> void:
	SteamServer.server_connected.connect(_register_server_on_server_browser)
	Steam.request_server_list_refresh_complete.connect(_on_server_list_request_refresh_complete)
	Steam.request_server_list_server_failed_to_respond.connect(_on_server_list_request_server_failed_to_respond)
	Steam.request_server_list_server_responded.connect(_on_server_list_request_server_responded)



func _register_server_on_server_browser() -> void:
	print("advertising server on server browser")
	SteamServer.setServerName(Server.config.sv_name)
	SteamServer.setMapName(MapManager.get_current_map().name)
	SteamServer.setMaxPlayerCount(Server.config.max_players)
	SteamServer.setPasswordProtected(Server.config.sv_password != "")
	SteamServer.setDedicatedServer(true)

	if Server.config.display_in_server_browser:
		SteamServer.setAdvertiseServerActive(true)


func request_server_list(filters: Array, target: Target=Target.INTERNET) -> int:
	_verify_filters_are_valid(filters)
	# https://partner.steamgames.com/doc/api/ISteamMatchmakingServers#MatchMakingKeyValuePair_t
	var old_request_id := Steam.get_server_list_request()
	Steam.cancelQuery(old_request_id)
	Steam.releaseRequest(old_request_id)

	var target_method: Callable
	match target:
		Target.INTERNET:
			target_method = Steam.requestInternetServerList
		Target.FAVOURITES:
			target_method = Steam.requestFavoritesServerList
		Target.HISTORY:
			target_method = Steam.requestHistoryServerList
		Target.FRIENDS:
			target_method = Steam.requestFriendsServerList
		_:
			push_error("Target server list is specified incorrectly!")

	var request_id: int = target_method.call(Steam.getAppID(), filters)
	if request_id <= 0:
		print("Request for server list failed, probably haven't initialised steam")
	return request_id


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
	var server_details: Dictionary = Steam.getServerDetails(server_index, request_id)
	query_response.emit(server_details)


func _on_server_list_request_server_responded(request_id: int, server_index: int) -> void:
	var server_details: Dictionary = Steam.getServerDetails(server_index, request_id)
	query_response.emit(server_details)


func _verify_filters_are_valid(filters: Array) -> void:
	for filter in filters:
		assert(filter.size() == 2)
		assert(filter[0] is String)
		assert(filter[1] is String)



func is_server_favourited(server_details: Dictionary) -> bool:
	# TODO dont call steam every time
	var favourite_servers := Steam.getFavoriteGames()
	for server: Dictionary in favourite_servers:
		var split: = String(server_details["connection_address"]).split(":")
		var ip := split[0]
		var port := int(split[1])

		if server.ip == ip and server.game_port == port and server.flags & Steam.FAVORITE_FLAG_FAVORITE:
			return true
	return false


func set_game_favourited(server_details: Dictionary, favourited: bool) -> void:
	var app_id := int(server_details.app_id)
	var split := String(server_details.connection_address).split(":")
	var ip := split[0]
	var port := int(split[1])
	var last_played := int(server_details.last_played)

	var query_port := int(String(server_details.query_address).split(":")[1])
	if favourited:
		Steam.addFavoriteGame(ip, port, query_port, Steam.FAVORITE_FLAG_FAVORITE, last_played)
	else:
		Steam.removeFavoriteGame(app_id, ip, port, query_port, Steam.FAVORITE_FLAG_FAVORITE)
