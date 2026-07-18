extends RefCounted
class_name RingBuffer

var _buffer: Array
var _size: int


func _init(size: int = 10) -> void:
	_buffer.resize(size)
	_size = size



func put(data: Variant, index: int) -> void:
	_buffer[index % _size] = data


func retrieve(index: int) -> Variant:
	return _buffer[index % _size]
