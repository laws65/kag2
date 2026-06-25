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
	# ALSO DELETE ALL BLOBS AND ALL MAP STUFF AND ERASE SNAPSHOT BUFFER


func server_load_gamemode(gamemode_path: String) -> void:
	assert(multiplayer.is_server(), "Can't call server_load_gamemode in client")
	Network.rpc_id_safe(0, _load_gamemode, gamemode_path)


@rpc("authority", "reliable", "call_local")
func _load_gamemode(gamemode_path: String, spawn_data: Dictionary={}) -> void:
	cleanup()

	var gamemode: GamemodeInfo = load(gamemode_path)

	var scripts := gamemode.scripts
	for script in scripts:
		var node := GamemodeScript.new()
		node.set_script(script)
		node.set_spawn_data(spawn_data)
		_scripts_parent.add_child(node)

	var old_gamemode := _current_gamemode
	_current_gamemode = gamemode
	gamemode_switch.emit(old_gamemode, _current_gamemode)


func get_gamemode_data() -> Dictionary:
	var out: Dictionary
	var script_nodes := _scripts_parent.get_children()
	for script: GamemodeScript in script_nodes:
		script.pass_spawn_data_into_dict(out)
	return out


#region HELPER FUNCS
func get_current_gamemode() -> GamemodeInfo:
	return _current_gamemode
#endregion
