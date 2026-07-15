extends Node


var debug: bool = false

var _rpc_queue: Array[RPCInfo]

var _current_transmit_time_ticks: int = -1
var _current_sender_id: int = -1

var buffer_incoming_rpcs: bool = false
var cull_buffer_before_time_ticks: int = -1

var accept_rpcs_after_time_ticks: int = -1


func _ready() -> void:
	multiplayer.peer_packet.connect(_on_packet_received)


func _on_packet_received(_sender_id: int, packet: PackedByteArray) -> void:
	var rpc_info: RPCInfo = RPCInfo.deserialised(packet)
	_generic_receive_rpc_id_safe(rpc_info)


func rpc_id_safe(target_id: int, method: Callable, ...args: Array) -> void:
	var node: Node = method.get_object()
	assert(
		is_instance_valid(node),
		"Cannot rpc a callable on its own, it must be a node's method"
	)

	var node_path := node.get_path()
	var method_name := method.get_method()

	var method_rpc_config := _get_rpc_config_from_node_method_name(node, method_name)
	assert(
		method_rpc_config.rpc_mode != MultiplayerAPI.RPC_MODE_AUTHORITY
		or multiplayer.get_unique_id() == 1,
		"Cannot call remote function %s as a client" % method_name
	)

	var transmit_time_ticks := NetworkedClock.time_ticks

	var rpc_info := RPCInfo.new(multiplayer.get_unique_id(), node_path, method_name, transmit_time_ticks, args)
	var serialised_rpc_info := RPCInfo.serialise(rpc_info)

	multiplayer.send_bytes(serialised_rpc_info, target_id, method_rpc_config.rpc_mode)

	if method_rpc_config.get("call_local"):
		_generic_receive_rpc_id_safe(rpc_info)


func _generic_receive_rpc_id_safe(rpc_info: RPCInfo) -> void:
	if debug:
		print("%s request call %s on %s" % [multiplayer.get_unique_id(), rpc_info.method_name, rpc_info.node_path])
	if _should_buffer_incoming_rpc(rpc_info.transmit_time_ticks):
		_rpc_queue.push_back(rpc_info)
		if debug:
			print("%s adding %s to queue" % [multiplayer.get_unique_id(), rpc_info.method_name])

	var node := get_tree().root.get_node_or_null(rpc_info.node_path)
	if not is_instance_valid(node):
		# TODO request node if it doesn't exist for me
		print("Cannot call %s on %s because it doesn't exist in this scene tree" % [rpc_info.method_name, rpc_info.node_path])
		return

	var method_rpc_config := _get_rpc_config_from_node_method_name(node, rpc_info.method_name)
	if method_rpc_config.rpc_mode == MultiplayerAPI.RPC_MODE_AUTHORITY and rpc_info.sender_id != 1:
		print("Received rpc from player %s on server only method %s, REJECTING" % [rpc_info.sender_id, rpc_info.method_name])
		return

	_current_sender_id = rpc_info.sender_id
	_current_transmit_time_ticks = rpc_info.transmit_time_ticks

	if debug:
		print("%s calling %s on %s" % [multiplayer.get_unique_id(), rpc_info.method_name, rpc_info.node_path])
	node.callv(rpc_info.method_name, rpc_info.args)


func run_old_rpcs() -> void:
	for rpc_data in _rpc_queue:
		if rpc_data.transmit_time_ticks < cull_buffer_before_time_ticks:
			print("%s skipping call %s on %s because it is too old" % [multiplayer.get_unique_id(), rpc_data.method_name, rpc_data.node_path])
			continue

		_generic_receive_rpc_id_safe(rpc_data)

		if debug:
			print("%s running old rpc %s on %s" % [multiplayer.get_unique_id(), rpc_data.method_name, rpc_data.node_path])

	_rpc_queue.clear()


func reset() -> void:
	_rpc_queue.clear()

	_current_transmit_time_ticks = -1
	_current_sender_id = -1

	buffer_incoming_rpcs = false
	cull_buffer_before_time_ticks = -1

	accept_rpcs_after_time_ticks = -1


#region HELPER FUNCS
func _should_buffer_incoming_rpc(transmit_time_ticks: int) -> bool:
	return (
		buffer_incoming_rpcs or
		(not multiplayer.is_server() and transmit_time_ticks < accept_rpcs_after_time_ticks) or
		(not multiplayer.is_server() and accept_rpcs_after_time_ticks < 0)
	)


func _get_rpc_config_from_node_method_name(node: Node, method_name: StringName) -> Dictionary:
	var node_script: Script = node.get_script()
	assert(
		is_instance_valid(node_script),
		"Node must have a script attached so that it can be called"
	)

	var config := node_script.get_rpc_config()
	assert(
		config.has(method_name),
		"Method %s is not configured for rpc on node %s " % [method_name, node.get_path()]
	)

	return config[method_name]


func get_rpc_transmit_time_ticks() -> int:
	return _current_transmit_time_ticks


func get_rpc_sender_id() -> int:
	return _current_sender_id
#endregion
