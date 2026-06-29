extends GamemodeScript


func _ready() -> void:
	Players.new_player_joined.connect(_on_Player_joined)
	Players.player_left.connect(_on_Player_left)


func _on_Player_joined(new_player: Player) -> void:
	if multiplayer.is_server():
		var random_spawn := Vector2(randi_range(-100, 100), randi_range(-100, 100))
		var blob := Blobs.server_create_blob("res://src/common/test_blob/test_blob.tscn", {"position": random_spawn})
		blob.server_set_player(new_player)


func _on_Player_left(player: Player) -> void:
	if multiplayer.is_server() and player.has_blob():
		var player_blob := player.get_blob()
		player_blob.server_die()
