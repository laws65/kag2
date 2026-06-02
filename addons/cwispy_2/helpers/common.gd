extends Node
class_name Common


static func serialise_dictionary(dictionary: Dictionary) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()

	var keys = dictionary.keys()

	for key_index in keys.size():
		var key = keys[key_index]
		var value = dictionary[key]
		buffer.put_string(key)
		buffer.put_var(value)

	return buffer.data_array


static func deserialise_dictionary(bytes_array: PackedByteArray) -> Dictionary:
	var buffer := StreamPeerBuffer.new()
	buffer.set_data_array(bytes_array)

	var dictionary := {}

	# this could potentially be causing an off-by-one error!
	while buffer.get_position() < buffer.get_size():
		var key := buffer.get_string()
		var value: Variant = buffer.get_var()
		dictionary[key] = value

	return dictionary
