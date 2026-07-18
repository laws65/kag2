extends Node
class_name Player


var props: Dictionary
static var secret_members: Array[StringName]


func _init(id: int, extra_data: Dictionary) -> void:
	name = str(id)
	props = extra_data


func get_id() -> int:
	return int(name)


## TODO: props aren't properly serialised
func serialise() -> PackedByteArray:
	var dict_to_serialise = props.duplicate()
	for secret_member in secret_members:
		dict_to_serialise.erase(secret_member)
	dict_to_serialise["id"] = get_id()
	var serialised := Common.serialise_dictionary(dict_to_serialise)
	return serialised


## TODO: props aren't properly deserialised
static func deserialise(serialised: PackedByteArray) -> Player:
	var deserialised := Common.deserialise_dictionary(serialised)
	var new_player_id: int = deserialised["id"]
	deserialised.erase("id")
	var new_player := Player.new(new_player_id, deserialised)
	return new_player


func get_prop(prop_name: StringName) -> Variant:
	return props.get(prop_name)


func set_prop(prop_name: StringName, value: Variant) -> void:
	props.set(prop_name, value)


func server_set_blob(new_blob: Blob) -> void:
	assert(multiplayer.is_server())
	if new_blob:
		server_set_blob_id(new_blob.get_id())
	else:
		server_set_blob_id(-1)


func server_set_blob_id(new_blob_id: int) -> void:
	assert(multiplayer.is_server())
	Blobs.server_set_ownership(get_id(), new_blob_id)


func has_blob() -> bool:
	return is_instance_valid(get_blob())


func get_blob_id() -> int:
	return Blobs.get_player_id_owner(get_id())


func get_blob() -> Blob:
	return Blobs.get_blob_by_id(get_blob_id())


func is_my_player() -> bool:
	return get_id() == multiplayer.get_unique_id()
