extends Node


signal gamemode_switch(old_gamemode, new_gamemode)

@onready var _scripts_parent: Node = self

var _current_gamemode: GamemodeInfo


func cleanup() -> void:
	var scripts := _scripts_parent.get_children()
	for script in scripts:
		script.cleanup()
		script.queue_free()
		_scripts_parent.remove_child(script)

	_current_gamemode = null


func server_load_gamemode(gamemode_path: String) -> void:
	assert(multiplayer.is_server(), "Can't call server_load_gamemode in client")
	Network.rpc_id_safe(0, _load_gamemode, gamemode_path)
	MapManager.server_load_random_map()


@rpc("authority", "reliable", "call_local")
func _load_gamemode(gamemode_path: String, spawn_data: Dictionary={}) -> void:
	cleanup()

	var gamemode: GamemodeInfo = load(gamemode_path)

	var script_paths := gamemode.script_paths
	for path in script_paths:
		var node := GamemodeScript.new()
		node.set_script(load(path))
		node.set_spawn_data(spawn_data)
		_scripts_parent.add_child(node)

	var old_gamemode := _current_gamemode
	_current_gamemode = gamemode
	gamemode_switch.emit(old_gamemode, _current_gamemode)


func _get_gamemode_data() -> Dictionary:
	var out: Dictionary
	var script_nodes := _scripts_parent.get_children()
	for script: GamemodeScript in script_nodes:
		script.pass_spawn_data_into_dict(out)
	return out


func get_complete_state_serialised() -> Array:
	var gamemode_path := _current_gamemode.resource_path
	var gamemode_data: Dictionary
	var script_nodes := _scripts_parent.get_children()
	for script: GamemodeScript in script_nodes:
		script.pass_spawn_data_into_dict(gamemode_data)

	return [gamemode_path, gamemode_data]


func deserialise_complete_state(state: Array) -> void:
	_load_gamemode(state[0], state[1])


func merge_complete_state(state: Array) -> void:
	pass # TODO IMPLEMENT


#region HELPER FUNCS
func get_current_gamemode() -> GamemodeInfo:
	return _current_gamemode
#endregion
