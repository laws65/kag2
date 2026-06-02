extends Node
class_name Player


var props: Dictionary

var _blob_id := -1

func _init(id: int, extra_data: Dictionary) -> void:
	name = str(id)
	props = extra_data


func get_id() -> int:
	return int(name)


## TODO: props aren't properly serialised
func serialise() -> PackedByteArray:
	var dict_to_serialise = props
	dict_to_serialise["id"] = get_id()
	var serialised := Common.serialise_dictionary(dict_to_serialise)
	var unserialised := Common.deserialise_dictionary(serialised)
	return serialised


## TODO: props aren't properly deserialised
static func deserialise(serialised: PackedByteArray) -> Player:
	var deserialised := Common.deserialise_dictionary(serialised)
	var new_player_id: int = deserialised["id"]
	deserialised.erase("id")
	var new_player := Player.new(new_player_id, deserialised)
	return new_player


func get_prop(prop_name: String) -> Variant:
	return props.get(prop_name)


func set_prop(prop_name: String, value: Variant) -> void:
	props.set(prop_name, value)


func server_set_blob(new_blob: Blob) -> void:
	assert(multiplayer.is_server())
	if new_blob:
		server_set_blob_id(new_blob.get_id())
	else:
		server_set_blob_id(-1)


func server_set_blob_id(new_blob_id: int) -> void:
	assert(multiplayer.is_server())
	_set_blob_id.rpc(new_blob_id)


@rpc("call_local", "reliable", "authority")
func _set_blob_id(new_blob_id: int, notify_own_blob: bool = true) -> void:
	var old_blob_id := _blob_id
	_blob_id = new_blob_id

	if notify_own_blob:
		var old_blob := Blobs.get_blob_by_id(old_blob_id)
		if old_blob:
			old_blob._set_player_id(-1, false)

		var new_blob := Blobs.get_blob_by_id(new_blob_id)
		if new_blob:
			new_blob._set_player_id(get_id(), false)


func has_blob() -> bool:
	return is_instance_valid(get_blob())


func get_blob_id() -> int:
	return _blob_id


func get_blob() -> Blob:
	return Blobs.get_blob_by_id(_blob_id)


func is_my_player() -> bool:
	return get_id() == Client.get_my_id()
