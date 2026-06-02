extends Node


var username := "hello"
var colour := Color("red")

var custom_join_data_callable = func():
	return {"username": username, "colour": colour.to_rgba64()}

var custom_client_join_data_validator = func(data: Dictionary):
	return data.has("username") and data["username"] != ""


func _ready() -> void:
	Players.new_player_joined.connect(_on_Player_joined)
	Players.player_left.connect(_on_Player_left)

	Client.get_join_data_callable = custom_join_data_callable
	Server.client_join_data_validator = custom_client_join_data_validator

	var args := OS.get_cmdline_args()
	if "--server" in args:
		Server.start_server()
		$Label2.text = "You are server"
	elif "--client" in args:
		Client.join_server()


func _on_Player_joined(new_player: Player) -> void:
	_rebuild_player_list()
	if multiplayer.is_server():
		var blob := Blobs.server_create_blob("res://src/common/test_blob/test_blob.tscn")
		blob.server_set_player(new_player)
	elif new_player.get_id() == Client.get_my_id():
		$Label2.text = "You are %s" % Client.get_my_id()


func _on_Player_left(_old_player: Player) -> void:
	_rebuild_player_list()


func _rebuild_player_list() -> void:
	$Label.text = ""
	var players := Players.get_players()
	for player in players:
		$Label.text += player.get_prop("username") + "- " + str(player.get_id()) + "\n"
		print(player.get_id())


func _on_fps_timer_timeout() -> void:
	$Label3.text = "FPS: %s" % int(Engine.get_frames_per_second())
