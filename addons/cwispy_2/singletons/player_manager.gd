extends Node


signal new_player_joined(new_player: Player)
signal player_left(old_player: Player)

@onready var _players_parent := self


func get_players() -> Array[Player]:
	var players = _players_parent.get_children()
	var casted: Array[Player]
	for player in players:
		casted.push_back(player as Player)
	return casted


func get_player_by_id(player_id: int) -> Player:
	return _players_parent.get_node_or_null(str(player_id))


@rpc("authority", "call_local", "reliable")
func register_player(player_id: int, extra_data: Dictionary={}) -> void:
	print("Trying to register player ", player_id)
	var new_player := Player.new(player_id, extra_data)
	_players_parent.add_child(new_player, true)
	new_player_joined.emit(new_player)


func add_old_player(player: Player) -> void:
	_players_parent.add_child(player, true)


@rpc("authority", "call_local", "reliable")
func deregister_player(player_id: int) -> void:
	print("Trying to deregister player ", player_id)
	var player := get_player_by_id(player_id)
	if not player:
		return
		
	_players_parent.remove_child(player)
	player.queue_free()
	player_left.emit(player)
