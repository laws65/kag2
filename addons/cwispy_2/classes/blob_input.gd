extends Node
class_name BlobInput

@export var blob: Blob


func _ready() -> void:
	assert(blob, "Must set blob")


func _should_collect_inputs() -> bool:
	return not multiplayer.is_server() and blob.is_my_blob()


func _serialise_inputs() -> PackedByteArray:
	push_error("Unimplemented")
	return PackedByteArray()


func _deserialise_inputs(bytes: PackedByteArray) -> void:
	push_error("Unimplemented")


func _get_empty_input() -> PackedByteArray:
	push_error("Unimplemented")
	return PackedByteArray()


func _get_predicted_input(prev_input: PackedByteArray) -> PackedByteArray:
	push_error("Unimplemented!")
	return PackedByteArray()
