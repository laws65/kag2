@icon ("res://addons/icons/human.svg")
extends Node
class_name Blob


signal player_id_changed(old_player_id: int, new_player_id: int)
signal death()

var _id: int = -1


@export var client_controlled: bool = false
@export var scene: Node
@export var input: BlobInput


func _init() -> void:
	NetworkedClock.tick.connect(_on_tick_internal)


func _on_tick_internal() -> void:
	if not scene.is_queued_for_deletion():
		_on_tick()


#region ABSTRACT
func _on_tick() -> void:
	pass


func rewind_to_snapshot(snapshot: Dictionary) -> void:
	pass


func get_spawn_data() -> Dictionary:
	return {}


func set_spawn_data(spawn_data: Dictionary) -> void:
	pass


func get_snapshot() -> Dictionary:
	return {}


func set_snapshot(snapshot: Dictionary) -> void:
	pass
#endregion


func server_set_player(new_player: Player) -> void:
	assert(multiplayer.is_server())
	if new_player:
		server_set_player_id(new_player.get_id())
	else:
		server_set_player_id(-1)


func server_set_player_id(new_player_id: int) -> void:
	assert(multiplayer.is_server())
	Blobs.server_set_ownership(new_player_id, get_id())


func server_die() -> void:
	assert(multiplayer.is_server(), "Can't kill blob on client")
	Blobs.server_kill_blob(self)


#region HELPER FUNCS
func set_id(new_id: int) -> void:
	_id = new_id


func get_id() -> int:
	return _id


func get_player_id() -> int:
	return Blobs.get_blob_id_owner(get_id())


func get_player() -> Player:
	return Players.get_player_by_id(get_player_id())


func has_player() -> bool:
	return is_instance_valid(get_player())


func is_my_blob() -> bool:
	# TODO potentially investigate why multiplayer could be null on the server
	return not multiplayer.is_server() and get_player_id() == multiplayer.get_unique_id()
#endregion
