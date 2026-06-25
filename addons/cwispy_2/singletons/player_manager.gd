extends Node


signal new_player_joined(new_player: Player)
signal player_left(old_player: Player)

@onready var _players_parent := self


@rpc("authority", "call_local", "reliable")
func register_player(player_id: int, extra_data: Dictionary={}) -> void:
	var new_player := Player.new(player_id, extra_data)
	_players_parent.add_child(new_player, true)
	new_player_joined.emit(new_player)


func add_old_player(player: Player) -> void:
	_players_parent.add_child(player, true)


@rpc("authority", "call_local", "reliable")
func deregister_player(player_id: int) -> void:
	var player := get_player_by_id(player_id)
	if not player:
		return

	_players_parent.remove_child(player)
	player.queue_free()
	player_left.emit(player)


func reset() -> void:
	var players := get_players()
	for player in players:
		player.queue_free()
		_players_parent.remove_child(player)


func pass_initial_spawn_data_into_dict(out: Dictionary) -> void:
	var serialised_players: Array[PackedByteArray]

	var players := get_players()
	for player in players:
		serialised_players.push_back(player.serialise())

	out["players"] = serialised_players


#region HELPER FUNCS
func get_players() -> Array[Player]:
	var players = _players_parent.get_children()
	var casted: Array[Player]
	for player in players:
		casted.push_back(player as Player)
	return casted


func get_player_by_id(player_id: int) -> Player:
	return _players_parent.get_node_or_null(str(player_id))


func get_local_player() -> Player:
	assert(not multiplayer.is_server(), "Local player does not exist on the server!")

	return get_player_by_id(multiplayer.get_unique_id())
#endregion
