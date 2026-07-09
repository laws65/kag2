extends Control


func _ready() -> void:
	Server.server_started.connect(func(): hide())
	Client.connection_established.connect(func(): hide())
	Client.left_server.connect(func(): show())


func _on_c_button_button_up() -> void:
	var username_input = %CUsername.text
	var ip_input = %CIP.text
	var port_input = %CPort.text
	if username_input and ip_input and port_input:
		if port_input.is_valid_int():
			Client.custom_join_data["username"] = username_input
			Client.join_server(ip_input, int(port_input))


func _on_s_button_button_up() -> void:
	Server.start_server()



func _on_browser_toggled(toggled_on: bool) -> void:
	if has_node("ServerBrowser"):
		$ServerBrowser.visible = toggled_on
