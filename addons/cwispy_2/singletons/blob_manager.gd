extends Node


signal blob_created(blob: Blob)
signal new_blob_created(new_blob: Blob)
signal on_blob_die(dead_blob: Blob)

var _blobs_parent: Node

var _blob_to_player_map: Dictionary[int, int] # BLOB_ID : PLAYER_ID
var _player_to_blob_map: Dictionary[int, int] # PLAYER_ID : BLOB_ID

var _blob_map: Dictionary[int, Blob]

var _next_blob_id = 10


func server_set_ownership(player_id: int, blob_id: int) -> void:
	assert(multiplayer.is_server())
	Network.rpc_id_safe(0, _set_ownership, player_id, blob_id)


@rpc("authority", "reliable", "call_local")
func _set_ownership(player_id: int, blob_id: int, cascade: bool = true) -> void:
	if player_id == -1 and blob_id == -1:
		return

	var old_player_id := get_blob_id_owner(blob_id)
	var old_blob_id := get_player_id_owner(player_id)

	if player_id != -1:
		_player_to_blob_map[player_id] = blob_id
	if blob_id != -1:
		_blob_to_player_map[blob_id] = player_id

	var blob := get_blob_by_id(blob_id)
	if blob:
		blob.player_id_changed.emit(old_player_id, player_id)

	if cascade:
		_set_ownership(old_player_id, -1, false)
		_set_ownership(-1, old_blob_id, false)


func server_create_blob(scene_filepath: String, spawn_data: Dictionary = {}) -> Blob:
	assert(multiplayer.is_server())

	var new_blob := _create_blob(scene_filepath, _next_blob_id, spawn_data)

	Network.rpc_id_safe(0, _create_server_blob, scene_filepath, _next_blob_id, spawn_data)
	_next_blob_id += 1
	blob_created.emit(new_blob)
	new_blob_created.emit(new_blob)

	return new_blob


@rpc("authority", "reliable")
func _create_server_blob(scene_filepath: String, blob_id: int, spawn_data: Dictionary, is_new: bool = true) -> void:
	var blob := _create_blob(scene_filepath, blob_id, spawn_data)

	blob_created.emit(blob)
	if is_new:
		new_blob_created.emit(blob)


func _create_blob(scene_filepath: String, blob_id: int, spawn_data: Dictionary) -> Blob:
	var packed_scene := load(scene_filepath) as PackedScene
	var new_scene: Node = packed_scene.instantiate()
	assert(new_scene.has_method(&"get_blob"))
	var new_blob: Blob = new_scene.get_blob()

	new_blob.set_id(blob_id)

	new_blob.set_spawn_data(spawn_data)
	_blob_map[blob_id] = new_blob
	_blobs_parent.add_child(new_scene, true)

	return new_blob


func server_kill_blob(blob: Blob) -> void:
	assert(multiplayer.is_server())
	assert(blob)
	Network.rpc_id_safe(0, _kill_blob_id, blob.get_id())


@rpc("authority", "call_local", "reliable")
func _kill_blob_id(blob_id: int) -> void:
	var blob := get_blob_by_id(blob_id)
	var scene := blob.scene
	scene.queue_free()
	scene.get_parent().remove_child(self)

	blob.death.emit()
	on_blob_die.emit(self)


func reset() -> void:
	var blobs := get_blobs()
	for blob in blobs:
		var scene := blob.scene
		scene.queue_free()
		_blobs_parent.remove_child(scene)


func get_complete_state_serialised() -> Array[Dictionary]:
	var blob_data: Array[Dictionary]
	var blobs := Blobs.get_blobs()
	for blob in blobs:
		var spawn_data := blob.get_spawn_data()
		blob_data.push_back({
			"filepath": blob.scene.scene_file_path,
			"id": blob.get_id(),
			"spawn_data": blob.get_spawn_data()
		})

	return blob_data


func deserialise_complete_state(blobs: Array[Dictionary]) -> void:
	for blob in blobs:
		var filepath: String = blob["filepath"]
		var spawn_data: Dictionary = blob["spawn_data"]
		var id: int = blob["id"]
		_create_blob(filepath, id, spawn_data)


func merge_complete_state(blobs: Array[Dictionary]) -> void:
	pass # TODO IMPLEMENT


#region HELPER FUNCS
func set_blobs_parent(blobs_parent: Node) -> void:
	_blobs_parent = blobs_parent


func get_blobs() -> Array[Blob]:
	return _blob_map.values()


func get_blob_by_id(blob_id: int) -> Blob:
	return _blob_map.get(blob_id)


func get_local_blob() -> Blob:
	assert(not multiplayer.is_server(), "Local blob does not exist on the server!")

	var local_player := Players.get_local_player()
	return local_player.get_blob()


func has_local_blob() -> bool:
	assert(not multiplayer.is_server(), "Local blob does not exist on server!")

	var local_player := Players.get_local_player()
	return local_player.has_blob()


func get_blob_id_owner(blob_id: int) -> int:
	return _blob_to_player_map.get(blob_id, -1)


func get_player_id_owner(player_id: int) -> int:
	return _player_to_blob_map.get(player_id, -1)
#endregion
