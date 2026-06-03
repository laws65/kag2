extends Node


var username := "hello"
var colour := Color("red")

var custom_join_data_callable = func():
	return {"username": username, "colour": colour.to_rgba64()}

var custom_client_join_data_validator = func(data: Dictionary):
	return data.has("username") and data["username"] != ""

var startup_immediately = true
func _ready() -> void:
	Server.server_started.connect(func():
		$CanvasLayer/Control/Label2.text = "You are server"; $CanvasLayer/Control/Control.hide())
	Client.connection_established.connect(func():
		$CanvasLayer/Control/Label2.text = "You are %s" % Client.get_my_id(); $CanvasLayer/Control/Control.hide())
	Players.new_player_joined.connect(_on_Player_joined)
	Players.player_left.connect(_on_Player_left)

	Client.get_join_data_callable = custom_join_data_callable
	Server.client_join_data_validator = custom_client_join_data_validator

	if startup_immediately:
		var args := OS.get_cmdline_args()
		if "--server" in args:
			Server.start_server()
		elif "--client" in args:
			Client.join_server()


func _on_Player_joined(new_player: Player) -> void:
	_rebuild_player_list()
	if multiplayer.is_server():
		var random_spawn := Vector2(randi_range(-100, 100), randi_range(-100, 100))
		var blob := Blobs.server_create_blob("res://src/common/test_blob/test_blob.tscn", {"position": random_spawn})
		blob.server_set_player(new_player)


func _on_Player_left(_old_player: Player) -> void:
	_rebuild_player_list()


func _rebuild_player_list() -> void:
	$CanvasLayer/Control/Label.text = ""
	var players := Players.get_players()
	for player in players:
		$CanvasLayer/Control/Label.text += player.get_prop("username") + "- " + str(player.get_id()) + "\n"
		print(player.get_id())


func _on_fps_timer_timeout() -> void:
	$CanvasLayer/Control/Label3.text = "FPS: %s" % int(Engine.get_frames_per_second())


func _on_c_button_button_up() -> void:
	var username_input = %CUsername.text
	var ip_input = %CIP.text
	var port_input = %CPort.text
	if username_input and ip_input and port_input:
		if port_input.is_valid_int():
			username = username_input
			Client.join_server(ip_input, int(port_input))


func _on_s_button_button_up() -> void:
	var port_input = %SPort.text
	if port_input and port_input.is_valid_int():
		Server.start_server(int(port_input))
