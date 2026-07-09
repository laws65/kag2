extends Control


var target: SteamServerBrowser.Target = SteamServerBrowser.Target.INTERNET


func _ready() -> void:
	Steamworks._initialise_on_client()
	Steamworks.server_browser.query_response.connect(_on_query_response)
	Steamworks.server_browser.query_finished.connect(_on_query_finished)
	_set_target(SteamServerBrowser.Target.INTERNET)


func _on_refresh_server_list_button_up() -> void:
	var filters = [
		["hasplayers", ""],
		["secure", ""]
	]
	_initiate_search(filters)


func _on_query_response(server_details: Dictionary) -> void:
	if server_details.success_response or $T.current_tab != SteamServerBrowser.Target.INTERNET:
		_add_server_to_list(server_details)
	print(server_details)


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
	var filters = [
		["hasplayers", ""],
		["secure", ""]
	]
	_initiate_search(filters)
