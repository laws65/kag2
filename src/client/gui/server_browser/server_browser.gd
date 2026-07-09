extends Control


var target: SteamServerBrowser.Target = SteamServerBrowser.Target.INTERNET


func _ready() -> void:
	Steamworks.server_browser.query_response.connect(_on_query_response)
	Steamworks.server_browser.query_finished.connect(_on_query_finished)
	if not get_tree().root.has_node("Main"):
		Steamworks._initialise_on_client()
		_refresh_server_list()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()


func _on_query_response(server_details: Dictionary) -> void:
	print(Steam.getAppID())
	print(server_details.connection_address)
	if server_details.success_response or target != SteamServerBrowser.Target.INTERNET:
		_add_server_to_list(server_details)


func _on_query_finished(_response: int) -> void:
	$RefreshServerList.text = "Refresh Browser"
	$RefreshServerList.disabled = false
	
	var list := _get_selected_tab_list()
	if list.get_children().is_empty():
		var no_servers_found_scene = load("res://src/client/gui/server_browser/no_servers_found.tscn")
		var instance = no_servers_found_scene.instantiate()
		list.add_child(instance)


func _get_selected_tab_list() -> Control:
	var target_tab = $T.get_child(target)
	return target_tab.get_node("ServerList")


func _add_server_to_list(server_details: Dictionary) -> void:
	var tab_list := _get_selected_tab_list()
	if tab_list.get_child_count() == 1:
		var child = tab_list.get_child(0)
		if child is Label:
			child.queue_free()
			tab_list.remove_child(child)
	var server_display_scene: PackedScene = load("res://src/client/gui/server_browser/server_display.tscn")
	var server_display: Control = server_display_scene.instantiate()
	server_display.set_display(server_details)
	server_display.toggled.connect(Steamworks.server_browser.set_game_favourited)
	_get_selected_tab_list().add_child(server_display)


func _clear_server_lists() -> void:
	var lists := [%Internet/ServerList, %Favourites/ServerList, %Friends/ServerList, %History/ServerList]
	for list in lists:
		var children = list.get_children()
		for child in children:
			child.hide()
			child.queue_free()


func _initiate_search(filters: Array) -> void:
	_clear_server_lists()

	Steamworks.server_browser.request_server_list(filters, target)
	$RefreshServerList.disabled = true
	$RefreshServerList.text = "Loading..."


func _set_target(new_target: SteamServerBrowser.Target) -> void:
	target = new_target
	_refresh_server_list()


func _refresh_server_list() -> void:
	var filters := _calculate_filters()
	_initiate_search(filters)


func _calculate_filters() -> Array:
	var filters := []
	
	if $%HideEmpty.button_pressed:
		filters.push_back(["hasplayers", ""])
	if not %ShowFull.button_pressed:
		filters.push_back(["notfull", ""])
	
	return filters


func _on_visibility_changed() -> void:
	if visible:
		_refresh_server_list()

# example server
#  "name": "32.216.76.65:7777", "connection_address": "32.216.76.65:7777", "query_address": "32.216.76.65:27015", "ping": 2000, "success_response": false, "no_refresh": true, "game_dir": "unrealtest", "map": "MP_CanalsG3", "description": "Gears of War 3", "app_id": 480, "players": 0, "max_players": 0, "bot_players": 8, "password": false, "secure": false, "last_played": 0, "server_version": 1000, "game_tags": "GearGameTDM_Newb_Content", "steam_id": 90288387899000833 
#  "name": "105.109.241.44:16261", "connection_address": "105.109.241.44:16261", "query_address": "105.109.241.44:16261", "ping": 2000, "success_response": false, "no_refresh": true, "game_dir": "zomboid", "map": "Muldraugh, KY", "description": "Project Zomboid", "app_id": 480, "players": 0, "max_players": 0, "bot_players": 0, "password": false, "secure": true, "last_played": 0, "server_version": 1000, "game_tags": "hidden;hosted;vanilla;VERSION:42.17", "steam_id": 90288382905803801 
