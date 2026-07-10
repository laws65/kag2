extends Control


func _ready() -> void:
	Server.server_started.connect(func():
		%Whoami.text = "You are server")
	Client.connection_established.connect(func():
		show()
		%Whoami.text = "You are %s" % multiplayer.get_unique_id())
	Players.new_player_joined.connect(_on_Player_joined)
	Players.player_left.connect(_on_Player_left)
	Blobs.blob_created.connect(
		func(_blob: Blob):
			_rebuild_blob_list()
	)
	Blobs.on_blob_die.connect(
		func (_blob: Blob):
			_rebuild_blob_list()
	)
	Client.left_server.connect(_on_left_server)


func _process(_delta: float) -> void:
	if multiplayer.is_server():
		%Time.text = str(NetworkedClock.time_ticks)
	else:
		%Time.text = str(NetworkedClock.network_time_ticks)
		%OldTime.text = str(NetworkedClock.time_ticks)

func _rebuild_blob_list() -> void:
	var blobs := Blobs.get_blobs()
	%BlobList.text = ""
	for blob in blobs:
		%BlobList.text += "%s \n" % blob.get_id()


func _on_Player_joined(_new_player: Player) -> void:
	_rebuild_player_list()


func _on_Player_left(_old_player: Player) -> void:
	_rebuild_player_list()


func _rebuild_player_list() -> void:
	%PlayerList.text = ""
	var players := Players.get_players()
	for player in players:
		%PlayerList.text += player.get_prop("username") + "- " + str(player.get_id()) + "\n"


func _on_fps_timer_timeout() -> void:
	%FPS.text = "FPS: %s" % int(Engine.get_frames_per_second())


func _on_left_server() -> void:
	hide()
