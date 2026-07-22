extends RefCounted
class_name RingBuffer

var _buffer: Array
var _size: int
var _greatest_index: int = -1


func _init(size: int = 50) -> void:
	_buffer.resize(size)
	_size = size


func put(data: Variant, index: int) -> void:
	_buffer[index % _size] = data
	if index > _greatest_index:
		_greatest_index = index


func retrieve(index: int) -> Variant:
	return _buffer[index % _size]


func clear() -> void:
	_buffer.fill(null)


func greatest() -> int:
	return _greatest_index


func print_values() -> void:
	for value in _buffer:
		if value != null:
			print(value)
