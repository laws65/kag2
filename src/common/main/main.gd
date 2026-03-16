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
	elif "--client" in args:
		Client.join_server()


func _on_Player_joined(_new_player: Player) -> void:
	$Label.text = ""
	var players := Players.get_players()
	for player in players:
		$Label.text += player.get_prop("username") + "\n"


func _on_Player_left(_old_player: Player) -> void:
	$Label.text = ""
	var players := Players.get_players()
	for player in players:
		$Label.text += player.get_prop("username") + "\n"
