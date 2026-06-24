class_name RPCInfo


var sender_id: int
var node_path: NodePath
var method_name: StringName
var transmit_time_ticks: int
var args: Array


func _init(sender_id: int, node_path: NodePath, method_name: StringName, transmit_time_ticks: int, args: Array) -> void:
	self.sender_id = sender_id
	self.node_path = node_path
	self.method_name = method_name
	self.transmit_time_ticks = transmit_time_ticks
	self.args = args


static func serialise(rpc_info: RPCInfo) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()

	buffer.put_64(rpc_info.sender_id)
	buffer.put_string(String(rpc_info.node_path))
	buffer.put_string(String(rpc_info.method_name))
	buffer.put_64(rpc_info.transmit_time_ticks)
	buffer.put_var(rpc_info.args)

	return buffer.data_array


static func deserialised(serialised_rpc_info: PackedByteArray) -> RPCInfo:
	var buffer := StreamPeerBuffer.new()
	buffer.set_data_array(serialised_rpc_info)

	return RPCInfo.new(
		buffer.get_64(),
		buffer.get_string(),
		buffer.get_string(),
		buffer.get_64(),
		buffer.get_var()
	)
