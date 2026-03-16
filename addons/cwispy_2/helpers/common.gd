extends Node
class_name Common


static func serialise_dictionary(dictionary: Dictionary[String, Variant]) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	
	var keys := dictionary.keys() as Array[String]
	
	for key_index in keys.size():
		var key := keys[key_index]
		var value: Variant = dictionary[key]
		buffer.put_string(key)
		buffer.put_var(value)

	return buffer.data_array


static func deserialise_dictionary(bytes_array: PackedByteArray) -> Dictionary[String, Variant]:
	var buffer := StreamPeerBuffer.new()
	buffer.set_data_array(bytes_array)
	
	var dictionary: Dictionary[String, Variant]
	
	for i in 2:
		var key := buffer.get_string()
		var value: Variant = buffer.get_var()
		dictionary[key] = value
	
	return dictionary
	
