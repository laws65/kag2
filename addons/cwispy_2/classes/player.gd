extends Node
class_name Player


var props: Dictionary


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
