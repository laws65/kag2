extends Node


signal new_player_joined(new_player: Player)
signal player_left(old_player: Player)
signal local_player_joined


var _players_map: Dictionary[int, Player]


@rpc("authority", "call_local", "reliable")
func register_player(player_id: int, extra_data: Dictionary={}) -> void:
	var new_player := Player.new(player_id, extra_data)
	_players_map[player_id] = new_player
	if player_id == multiplayer.get_unique_id():
		local_player_joined.emit()
	new_player_joined.emit(new_player)


func add_old_player(player: Player) -> void:
	_players_map[player.get_id()] = player


@rpc("authority", "call_local", "reliable")
func deregister_player(player_id: int) -> void:
	var player := get_player_by_id(player_id)
	if not player:
		return

	player_left.emit(player)


func reset() -> void:
	_players_map.clear()


func get_complete_state_serialised() -> Array[PackedByteArray]:
	var serialised_players: Array[PackedByteArray]

	var players := get_players()
	for player in players:
		serialised_players.push_back(player.serialise())

	return serialised_players


func deserialise_complete_state(serialised_players: Array[PackedByteArray]) -> void:
	for serialised_player in serialised_players:
		var deserialised_player := Player.deserialise(serialised_player)
		add_old_player(deserialised_player)


func merge_complete_state(serialised_players: Array[PackedByteArray]) -> void:
	pass # TODO IMPLEMENT


#region HELPER FUNCS
func get_players() -> Array[Player]:
	return _players_map.values()


func get_player_by_id(player_id: int) -> Player:
	return _players_map.get(player_id)


func has_player(player_id: int) -> bool:
	return _players_map.get(player_id)


func get_local_player() -> Player:
	assert(not multiplayer.is_server(), "Local player does not exist on the server!")

	return get_player_by_id(multiplayer.get_unique_id())
#endregion
