extends Node


var _map_parent: Node2D
var _current_map: Map


func cleanup() -> void:
	if is_instance_valid(_current_map):
		_current_map.cleanup()
		_current_map.queue_free()
		_map_parent.remove_child(_current_map)


func server_load_random_map() -> void:
	assert(multiplayer.is_server(), "Can't load random map on client")

	var map_list := GamemodeManager.get_current_gamemode().map_paths

	var random_map_path := map_list.pick_random()
	Network.rpc_id_safe(0, _load_map, random_map_path)


@rpc("reliable", "authority", "call_local")
func _load_map(map_path: String, map_data: Dictionary={}) -> void:
	cleanup()

	var map: PackedScene = load(map_path)
	var map_instance: Map = map.instantiate()

	map_instance.set_spawn_data(map_data)
	_current_map = map_instance
	_map_parent.add_child(map_instance)


#region HELPER FUNCS
func get_current_map() -> Map:
	return _current_map


func set_map_parent(map_parent: Node2D) -> void:
	_map_parent = map_parent
#endregion
