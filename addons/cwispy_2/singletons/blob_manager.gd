extends Node


@onready var _blobs_parent := get_node("/root/Main/World/Blobs")


func get_blobs() -> Array[Blob]:
	var blobs = _blobs_parent.get_children()
	var casted: Array[Blob]
	for blob: Blob in blobs:
		casted.push_back(blob)
	return casted


func get_blob_by_id(blob_id: int) -> Blob:
	var blobs := _blobs_parent.get_children()
	for blob in blobs:
		if blob.get_id() == blob_id:
			return blob as Blob
	return null


func server_create_blob(blob_filepath: String, spawn_data: Dictionary = {}) -> Blob:
	assert(multiplayer.is_server())

	var new_blob := _create_blob(blob_filepath, spawn_data)

	var new_blob_id := new_blob.get_instance_id()
	new_blob.set_id(new_blob.get_instance_id())
	spawn_data["id"] = new_blob_id

	Network.rpc_id_safe(0, _create_server_blob, blob_filepath, spawn_data)

	return new_blob


@rpc("authority", "reliable")
func _create_server_blob(blob_filepath: String, spawn_data: Dictionary, is_new: bool = true) -> void:
	_create_blob(blob_filepath, spawn_data)


func _create_blob(blob_filepath: String, spawn_data: Dictionary) -> Blob:
	var packed_scene := load(blob_filepath) as PackedScene
	var new_blob: Blob = packed_scene.instantiate()

	new_blob.set_spawn_data(spawn_data)
	_blobs_parent.add_child(new_blob, true)

	return new_blob
