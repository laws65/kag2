extends HBoxContainer


signal toggled(server_details: Dictionary, toggled_on: bool)

var server: Dictionary


func set_display(server_details: Dictionary) -> void:
	server = server_details
	%Favourite.button_pressed = Steamworks.server_browser.is_server_favourited(server_details)
	%ServerName.text = server_details["name"]
	%MapName.text = server_details["map"]
	%PlayerCount.text = "%s/%s" % [server_details["players"], server_details["max_players"]]
	%Ping.text = str(server_details["ping"]) if server_details["success_response"] else "Not responding..."


func _on_favourite_toggled(toggled_on: bool) -> void:
	toggled.emit(server, toggled_on)
