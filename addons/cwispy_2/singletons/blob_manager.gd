extends Node


signal blob_created(blob: Blob)
signal new_blob_created(new_blob: Blob)

@onready var _blobs_parent := get_node("/root/Main/World/Blobs")


func server_create_blob(blob_filepath: String, spawn_data: Dictionary = {}) -> Blob:
	assert(multiplayer.is_server())

	var new_blob := _create_blob(blob_filepath, spawn_data)

	var new_blob_id := new_blob.get_instance_id()
	new_blob.set_id(new_blob.get_instance_id())
	spawn_data["id"] = new_blob_id

	Network.rpc_id_safe(0, _create_server_blob, blob_filepath, spawn_data)

	blob_created.emit(new_blob)
	new_blob_created.emit(new_blob)

	return new_blob


@rpc("authority", "reliable")
func _create_server_blob(blob_filepath: String, spawn_data: Dictionary, is_new: bool = true) -> void:
	var blob := _create_blob(blob_filepath, spawn_data)

	blob_created.emit(blob)
	if is_new:
		new_blob_created.emit(blob)


func _create_blob(blob_filepath: String, spawn_data: Dictionary) -> Blob:
	var packed_scene := load(blob_filepath) as PackedScene
	var new_blob: Blob = packed_scene.instantiate()

	new_blob.set_spawn_data(spawn_data)
	_blobs_parent.add_child(new_blob, true)

	return new_blob


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
